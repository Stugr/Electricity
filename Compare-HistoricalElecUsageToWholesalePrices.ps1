# get last modified csv file from the usage folder
# get detailed report meter data from here for citipower https://www.citipower.com.au/customers/myenergy/
$usageCsv = (Get-Item "$PSScriptRoot\usage\*.csv" | Sort {$_.LastWriteTime} | select -last 1)

$pricesDir = "$PSScriptRoot\prices"

# create output dir
$outputDir = "$PSScriptRoot\output\"
New-Item -Path $outputDir -Type Directory -Force | Out-Null

# values taken manually from https://api.amberelectric.com.au/prices/listprices for now - are current (2020) values so won't be accurate for 2018/2019
$fixedKWHprice = 0.1086346
$lossFactor = 1.0419

# add in our incumbent pricing
$incumbentPricingDateRanges = @(
    [pscustomobject][ordered]@{
        'startDate' = '01/01/2018'; #ddMMyyyy
        'endDate' = '06/10/2019'; #ddMMyyyy
        'supplyCharge' = 0.616;
        'peakRate' = 0.1463;
    },
    [pscustomobject][ordered]@{
        'startDate' = '07/10/2019'; #ddMMyyyy
        'endDate' = Get-Date; #ddMMyyyy
        'supplyCharge' = 1.122;
        'peakRate' = 0.1991;
    }
)

# convert incumbent pricing to datetime objects
foreach ($range in $incumbentPricingDateRanges) {
    if ($range.startDate -isNot [DateTime]) {
        $range.startDate = [datetime]::ParseExact($range.startDate, "dd/MM/yyyy",$null)    
    }
    
    if ($range.endDate -isNot [DateTime]) {
        $range.endDate = [datetime]::ParseExact($range.endDate, "dd/MM/yyyy",$null)    
    }
}

# sort incumbent pricing array by earliest date
$incumbentPricingDateRanges = $incumbentPricingDateRanges | Sort-Object startDate

# csv doesn't have a header, so  create headers to hold all 48 time intervals (1-48)
# start at -1 to leave 2 columns at the front spare
$header = -1..48 | % { "IntervalValue$_" }
$header[0] = "RecordIndicator"
$header[1] = "IntervalDate"

# get data from csv ignoring first 2 rows and supplying custom headers (can't use import-csv because of this)
# we only want recordIndicator 300 which is Interval data record
$usageData = Get-Content $usageCsv | Select-Object -Skip 2 | Out-String | ConvertFrom-Csv -Header $header | ? { $_.recordIndicator -eq 300 }

# add member properties to our usageData to hold pricing
$usageData | Add-Member "TotalDayKWH" -membertype noteproperty -Value 0
$usageData | Add-Member "TotalDayExGST" -membertype noteproperty -Value 0
$usageData | Add-Member "TotalDayIncGST" -membertype noteproperty -Value 0
$usageData | Add-Member "TotalDayAmber" -membertype noteproperty -Value 0 # not including ambers $10/mth supply charge - added later when graphing/analysing
$usageData | Add-Member "TotalDayIncumbent" -membertype noteproperty -Value 0 # this will include the supply charge that normal retailers charge
1..48 | % {
    $usageData | Add-Member "IntervalExGSTPrice$_" -membertype noteproperty -Value 0
    $usageData | Add-Member "IntervalExGSTCost$_" -membertype noteproperty -Value 0
    $usageData | Add-Member "IntervalIncGSTPrice$_" -membertype noteproperty -Value 0
    $usageData | Add-Member "IntervalIncGSTCost$_" -membertype noteproperty -Value 0
    $usageData | Add-Member "IntervalAmberPrice$_" -membertype noteproperty -Value 0
    $usageData | Add-Member "IntervalAmberCost$_" -membertype noteproperty -Value 0
    $usageData | Add-Member "IntervalIncumbentPrice$_" -membertype noteproperty -Value 0
    $usageData | Add-Member "IntervalIncumbentCost$_" -membertype noteproperty -Value 0
}

# create array of objects to hold summarisation of each internalValue
$usageSummarised = 1..48 | % { [pscustomobject][ordered]@{
    "name" = "IntervalValue$_";
    "count" = 0;
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

        # import prices, shifting back the timestamps by 30 mins to align with the start of the 30 min interval instead of the end
        # divide rrp by 1000 to shift from megawatt hour to kilowatt hour, and calculate a gst inclusive price too
        if ($csvFile = (Get-Item "$pricesDir\*$($rowDateOnly.ToString("yyyyMM"))*.csv").fullname) {
            $prices = Import-Csv $csvFile | select @{N="settlementdate";E={([DateTime]$_.settlementdate).addhours(-.5)}}, @{N="exGst";E={$_.rrp/1000}}, @{N="incGst";E={($_.rrp/1000)*1.1}}
        }
    }

    # get prices that match that day (will make the next filtering by hour much quicker)
    # logic was originally written to search instead of trusting the sorting of the file, so might re-write someday
    $datePrices = $prices | ? { $_.settlementdate.date -eq $rowDateOnly.date }

    # get incumbent prices that match that day
    $incumbentPrices = $incumbentPricingDateRanges | ? { $rowDateOnly -ge $_.startDate -and $rowDateOnly -le $_.endDate }

    # add supply charge
    $row.TotalDayIncumbent = $incumbentPrices.supplyCharge

    # loop through the days intervals
    foreach ($i in 1..48) {
        # add hours and minutes to the usable datetime
        $rowDateTime = $rowDateOnly.AddHours(0.5 * ($i - 1))

        # find the matching price for the interval
        $matchingPrice = $datePrices | ? { $_.settlementdate -eq $rowDateTime }

        # add member properties to our usageData to hold pricing
        $row."IntervalExGSTPrice$i" = $matchingPrice.exGST
        $row."IntervalExGSTCost$i" = $matchingPrice.exGST * $row."IntervalValue$i"
        $row."IntervalIncGSTPrice$i" = $matchingPrice.incGST
        $row."IntervalIncGSTCost$i" = $matchingPrice.incGST * $row."IntervalValue$i"
        $row."IntervalAmberPrice$i" = $fixedKWHprice + ($matchingPrice.incGST * $lossFactor)
        $row."IntervalAmberCost$i" = $row."IntervalAmberPrice$i" * $row."IntervalValue$i"
        $row."IntervalIncumbentPrice$i" = $incumbentPrices.peakRate
        $row."IntervalIncumbentCost$i" = $row."IntervalIncumbentPrice$i" * $row."IntervalValue$i"
        $row.TotalDayExGST += $row."IntervalExGSTCost$i"
        $row.TotalDayIncGST += $row."IntervalIncGSTCost$i"
        $row.TotalDayAmber += $row."IntervalAmberCost$i"
        $row.TotalDayIncumbent += $row."IntervalIncumbentCost$i"
        $row.TotalDayKWH += $row."IntervalValue$i"
    }
    
    # increment counter for progress bar
    $rowCounter++
}

# export usage data with pricing
$usageData | Export-Csv -NoTypeInformation (Join-Path $outputDir "usageWithPricing.csv") -Force
