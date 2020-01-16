# get last modified csv file from the usage folder
# get detailed report meter data from here for citipower https://www.citipower.com.au/customers/myenergy/
$usageCsv = (Get-Item "$PSScriptRoot\usage\*.csv" | Sort {$_.LastWriteTime} | select -last 1)

$pricesDir = "$PSScriptRoot\prices"

# create output dir
$outputDir = "$PSScriptRoot\output\"
New-Item -Path $outputDir -Type Directory -Force | Out-Null

# csv doesn't have a header, so  create headers to hold all 48 time intervals (1-48)
# start at -1 to leave 2 columns at the front spare
$header = -1..48 | % { "IntervalValue$_" }
$header[0] = "RecordIndicator"
$header[1] = "IntervalDate"

# get data from csv ignoring first 2 rows and supplying custom headers (can't use import-csv because of this)
# we only want recordIndicator 300 which is Interval data record
$usageData = Get-Content $usageCsv | Select-Object -Skip 2 | Out-String | ConvertFrom-Csv -Header $header | ? { $_.recordIndicator -eq 300 }

# add member properties to our usageData to hold pricing
$usageData | Add-Member "TotalDayExGST" -membertype noteproperty -Value 0
$usageData | Add-Member "TotalDayIncGST" -membertype noteproperty -Value 0
1..48 | % {
    $usageData | Add-Member "IntervalExGSTPrice$_" -membertype noteproperty -Value 0
    $usageData | Add-Member "IntervalExGSTCost$_" -membertype noteproperty -Value 0
}

# create array of objects to hold summarisation of each internalValue
$usageSummarised = 1..48 | % { [pscustomobject][ordered]@{
    "name" = "IntervalValue$_"
    "count" = 0
    "average" = 0;
    "sum" = 0;
    "maximum" = 0;
    "minimum" = 0;
}}

# loop through our 48 internalvalues to summarise
foreach ($obj in $usageSummarised) {
    # get summary for all values in each column
    $measured = $usageData.($obj.name) | Measure-Object -Average -Sum -Maximum -Minimum
    $obj.count = $measured.Count
    $obj.average = $measured.Average
    $obj.sum = $measured.Sum
    $obj.maximum = $measured.Maximum
    $obj.minimum = $measured.Minimum
}

# export summary to csv
$usageSummarised | Export-Csv -NoTypeInformation (Join-Path $outputDir "usageSummarised.csv") -Force

$rowCounter = 0
$currentMonth = $null
# loop through each day of usage data
foreach ($row in $usageData) {
    # write progress bar
    Write-Progress -Activity "Matching price data" -Status "$($row.IntervalDate) (day $($rowCounter+1) of $($usageData.count))" -PercentComplete ($rowCounter/$usageData.count*100)

    # convert intervaldate to a usable datetime (ignoring minutes)
    $rowDateOnly = [datetime]::ParseExact($row.IntervalDate, "yyyyMMdd",$null)

    # if we are into a new month
    if ($rowDateOnly.Month -ne $currentMonth) {
        $currentMonth = $rowDateOnly.Month

        # read this month and the next (due to the shifting back of 30 mins)
        # import prices, shifting back the timestamps by 30 mins to align with the start of the 30 min interval instead of the end
        # divide rrp by 1000 to shift from megawatt hour to kilowatt hour, and calculate a gst inclusive price too
        $prices = Import-Csv -Path @((Get-Item "$pricesDir\*$($rowDateOnly.ToString("yyyyMM"))*.csv").fullname,(Get-Item "$pricesDir\*$($rowDateOnly.AddMonths(1).ToString("yyyyMM"))*.csv").fullname) | select @{N="settlementdate";E={([DateTime]$_.settlementdate).addhours(-.5)}}, @{N="exGst";E={$_.rrp/1000}}, @{N="incGst";E={($_.rrp/1000)*1.1}}
    }

    # get prices that match that day (will make the next filtering by hour much quicker)
    $datePrices = $prices | ? { $_.settlementdate.date -eq $rowDateOnly.date }

    # loop through the days intervals
    foreach ($i in 1..48) {
        # add hours and minutes to the usable datetime
        $rowDateTime = $rowDateOnly.AddHours(0.5 * ($i - 1))

        # find the matching price for the interval
        $matchingPrice = $datePrices | ? { $_.settlementdate -eq $rowDateTime }

        # add member properties to our usageData to hold pricing
        $row."IntervalExGSTPrice$i" = $matchingPrice.exGST
        $row."IntervalExGSTCost$i" = $matchingPrice.exGST * $row."IntervalValue$i"
        $row.TotalDayExGST += $matchingPrice.exGST * $row."IntervalValue$i"
        $row.TotalDayIncGST += $matchingPrice.incGST * $row."IntervalValue$i"
    }
    
    # increment counter for progress bar
    $rowCounter++
}

# export usage data with pricing
$usageData | ? { $_.IntervalDate -like "201*"} | Export-Csv -NoTypeInformation (Join-Path $outputDir "usageWithPricing.csv") -Force
