$pricesDir = "$PSScriptRoot\prices"

$years = 2018,2019

# create output dir
$outputDir = "$PSScriptRoot\output\"
New-Item -Path $outputDir -Type Directory -Force | Out-Null

foreach ($year in $years) {

    # import prices, shifting back the timestamps by 30 mins to align with the start of the 30 min interval instead of the end
    # divide rrp by 1000 to shift from megawatt hour to kilowatt hour, and calculate a gst inclusive price too
    $prices = Import-Csv (Get-Item "$pricesDir\*$year*.csv") | select @{N="settlementdate";E={([DateTime]$_.settlementdate).addhours(-.5)}}, @{N="exGst";E={$_.rrp/1000}}, @{N="incGst";E={($_.rrp/1000)*1.1}}

    # get unique hour:min
    $timeIntervals = $prices | select -Unique @{N="hour";E={($_.settlementdate.hour)}}, @{N="minute";E={"{0:00}" -f $_.settlementdate.minute}} | sort hour, minute

    # create array of objects to hold summarisation of each internalValue
    $pricesSummarised = 1..48 | % { [pscustomobject][ordered]@{
        "name" = "IntervalValue$_"
        "count" = 0
        "average" = 0;
        "sum" = 0;
        "maximum" = 0;
        "minimum" = 0;
        "time" = "";
    }}

    $i = 0
    foreach ($time in $timeIntervals) {
        $measured = $prices | ? { $_.settlementdate.hour -eq $time.hour -and $_.settlementdate.minute -eq $time.minute} | Measure-Object -Average -Sum -Maximum -Minimum -Property exGST
        $pricesSummarised[$i].count = $measured.Count
        $pricesSummarised[$i].average = $measured.Average
        $pricesSummarised[$i].sum = $measured.Sum
        $pricesSummarised[$i].maximum = $measured.Maximum
        $pricesSummarised[$i].minimum = $measured.Minimum
        $pricesSummarised[$i].time = "$($time.hour):$($time.minute)"
        $i++
    }

    $pricesSummarised | Export-Csv -NoTypeInformation (Join-Path $outputDir "pricesSummarised_$year.csv") -Force
}

