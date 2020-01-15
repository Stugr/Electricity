# Electricity
Download historical wholesale electricity prices
------------------------------------------------
Run `Get-HistoricalElecWholesalePrices.ps1` to download victorias last 2 years of prices (change state and years at the top of the code if you want different data)

Do a quick comparison of the prices
-----------------------------------
Completely optional, run `Compare-HistoricalElecWholesalePrices.ps1` if you want to get a summary output (avg by time etc) of the prices in csv (`pricesSummarised_2018.csv` and `pricesSummarised_2019.csv`)

|name|count                        |average|sum                                          |maximum|minimum |time|
|----|-----------------------------|-------|---------------------------------------------|-------|--------|----|
|IntervalValue1|365                          |0.0801255068493151|29.24581                                     |0.26864|0.00414 |0:00|
|IntervalValue2|365                          |0.07466|27.2509                                      |0.19801|-1E-05  |0:30|
|IntervalValue3|365                          |0.0683841095890411|24.9602                                      |0.22744|-0.15792|1:00|
|IntervalValue4|365                          |0.0629090410958904|22.9618                                      |0.21583|-0.55462|1:30|

Compare your usage data against wholesale prices
------------------------------------------------
This is the point of this repo

Download your detailed report meter data (csv) from here for citipower: https://www.citipower.com.au/customers/myenergy/ and place it in the input folder

Then run `Compare-HistoricalElecUsageToWholesalePrices.ps1` which will take a while but spit you out `usageSummarised.csv` (similar to the pricing summary) and `usageWithPricing.csv`

|IntervalDate|TotalDayExGST                |TotalDayIncGST|IntervalValue1                               |IntervalExGSTPrice1|IntervalExGSTCost1|IntervalValue2|IntervalExGSTPrice2|IntervalExGSTCost2|
|------------|-----------------------------|--------------|---------------------------------------------|-------------------|------------------|--------------|-------------------|------------------|
|20180115    |1.07302777                   |1.180330547   |0.264                                        |0.07106            |0.01875984        |0.238         |0.064              |0.015232          |
|20180116    |1.67929872                   |1.847228592   |0.353                                        |0.06311            |0.02227783        |0.217         |0.07079            |0.01536143        |
|20180117    |1.63294493                   |1.796239423   |0.166                                        |0.07911            |0.01313226        |0.116         |0.09231            |0.01070796        |
|20180118    |12.65782471                  |13.92360718   |0.303                                        |0.06633            |0.02009799        |0.284         |0.06418            |0.01822712        |
|20180119    |7.59171565                   |8.350887215   |0.273                                        |0.08561            |0.02337153        |0.291         |0.0806             |0.0234546         |

`TotalDayExGST` and `TotalDayIncGST` are summed for you from all interval periods

`IntervalExGSTPrice1/2/etc` is the wholesale price per kwh and `IntervalExGSTCost1/2/etc` is the `usage in kwh (IntervalValue1/2/etc) * price per kwh`

