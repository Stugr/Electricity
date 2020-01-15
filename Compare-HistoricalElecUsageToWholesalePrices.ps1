# get last modified csv file from the usage folder
$usageCsv = (Get-Item "$PSScriptRoot\usage\*.csv" | Sort {$_.LastWriteTime} | select -last 1)

# csv doesn't have a header, so  create headers to hold all 48 time intervals (1-48)
# start at -1 to leave 2 columns at the front spare
$header = -1..48 | % { "IntervalValue$_" }
$header[0] = "RecordIndicator"
$header[1] = "IntervalDate"

# get data from csv ignoring first 2 rows and supplying custom headers (can't use import-csv because of this)
# we only want recordIndicator 300 which is Interval data record
$usageData = Get-Content $usageCsv | Select-Object -Skip 2 | Out-String | ConvertFrom-Csv -Header $header | ? { $_.recordIndicator -eq 300 }

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

