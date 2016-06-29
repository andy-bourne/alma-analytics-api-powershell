# alma-analytics-api-powershell

Powershell code to run Alma Analytics reports

This is the README.md file


This code is a subset of a wider analytics project, extracted for demonstration purposes; it is distinctly rough in many places but demonstrates some of the essential feature of using the Alma Analytics API.  From time to time I may extract new code from the main project and update this demo code; previous versions will still be visible via Github's 'diff' feature.

The Alma Analytics API features reflected in the code are:
- formation of the URL for the GET request, including
  - creation of an "SAWX filter" (XML fragment) to pass data into a parameterized report
- handling of [some] error conditions
- handling of the data returned by the API call
- handling of the Alma Analytics API 'paging' and 'resumption key' features
- export of data to a csv file
- handling of the generic "Column0","Column1", etc field names in the output


The script `alma_analytics_API_demo.ps1` is the starting point.

To use it you would have to edit the line...
```
$report_path = "%2Fshared%2FSalford University%2FReports%2FFulfillment%2FCirculation Coordinator%2Fwork_in_progress_current_users_given_cutoff_date_andy_bourne"
```
...to refer to one of your own reports and you would have to edit the line...
```
$private:apikey = "************************************"
```
... to use your own Alma Analytics API key

`alma_analytics_API_demo.ps1` uses a function called `run_snapshot_report` from the file `alma_analytics_API_run_snapshot_report.ps1`. 
This function is used to invoke an Alma Analytics report that is set up to expect a single 'prompted' parameter called `"User Details"."Expiry Date"`. 
`run_snapshot_report` basically just handles the creation of an "SAWX filter" (XML fragment) containing a date created from a year and month number then calls the `run_report_and_output_to_csv` function.

In `alma_analytics_API_core_utilities.ps1`,
`run_report_and_output_to_csv` handles the Alma Analytics API 'paging' and 'resumption key' features, and
[finally!] `get_data_from_Alma_Analytics_API_web_service` is where we actually send a GET request to the API, as shown below...
```
if ($resumption_token -eq $null){
   $rest_url = "https://api-eu.hosted.exlibrisgroup.com/almaws/v1/analytics/reports?path=$report_path&apikey=$apikey&limit=$limit&filter=$filter"
}else{
   $rest_url = "https://api-eu.hosted.exlibrisgroup.com/almaws/v1/analytics/reports?token=$resumption_token&apikey=$apikey&limit=$limit"
}
...
$response = Invoke-WebRequest -uri $rest_url
```

Writing the output to a csv file is very easy thanks to Powershell's Export-Csv function (referred to as a 'cmdlet' in Powershell terms)...
```
$data_chunk.Row | Export-Csv $output_filename -NoTypeInformation -Append -Force
```
... where `$data_chunk.Row` is an object containing multiple rows of output from the report.


There is also a function called `copy_with_new_header_line` that just copies from one csv file to another, changing the first line from something like
```
"Column0","Column1","Column2","Column3","Column4","Column5"
```
to something like
```
"dummy","department_name","expiry_date","username","user_group_code","user_group_name"
```
i.e. this is dealing with the rather unhelpful feature of the API where the output dataset does include any meaningful field names.



