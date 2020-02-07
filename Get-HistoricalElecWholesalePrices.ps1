# Download data from https://www.aemo.com.au/Electricity/National-Electricity-Market-NEM/Data-dashboard#aggregated-data
$state = "VIC"
$years = 2018,2019,2020

# create prices dir
$pricesDir = "$PSScriptRoot\prices"
New-Item -Path $pricesDir -Type Directory -Force | Out-Null

# loop through years
foreach ($year in $years) {
    # loop through months
    1..12 | % {
        # pad month to 2 places
        $month = "{0:00}" -f $_

        # convert month and year to datetime object
        $pullDate = [datetime]::ParseExact("$year$($month)01", "yyyyMMdd",$null)

        # don't bother trying to pull months that are in the future
        if ($pulldate -gt (Get-Date)) {
            break
        } else {
            $file = "PRICE_AND_DEMAND_$year$($month)_$($state)1.csv"
            # download file
            Invoke-WebRequest -Uri "https://www.aemo.com.au/aemo/data/nem/priceanddemand/$file" -OutFile (Join-Path $pricesDir $file)
        }
    }
}

