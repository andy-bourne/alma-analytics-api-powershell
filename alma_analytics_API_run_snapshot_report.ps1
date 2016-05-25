. .\alma_analytics_API_core_utilities.ps1		# run_report_and_output_to_csv, copy_with_new_header_line

#====================================================================================================
function run_snapshot_report ($apikey, $report_name, $report_path, $original_header_line, $new_header_line, $calendar_year, $month_number, $temp) {

#--------------------------------------------------------------------------------
#Define an sawx filter object (for Alma Analytics)

#Suppose we want to run this for the calendar month February 2016
#Input params are (2016,02), calculate (string concat) a date 01/02/2016 - condition is then >=01/02/2016
#Note: the report for February 2016 would normally be run in early March 2016 - i.e. at the time we run
#      the report we are trying to get a snapshot of current active users in existence at the end of February,
#      with the assumption that this set of users will include all users who were active during the whole 
#      of that month.  We could just run a report that lists all usernames in existece at the time we run
#      the report, but that would includes thousands of usernames that have expired.
#      To limit this, we pass a single date parameter to the report - in this case, 1st February 2016.

$field1 = '"User Details"."Expiry Date"'
$value1 = "$calendar_year-$month_number-01"		# (2016,02) -> "2016-02-01"

$filter_template = @"
<sawx:expr xsi:type=`"sawx:comparison`" op=`"greaterOrEqual`" xmlns:saw=`"com.siebel.analytics.web/report/v1.1`"
xmlns:sawx=`"com.siebel.analytics.web/expression/v1.1`" xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`" 
xmlns:xsd=`"http://www.w3.org/2001/XMLSchema`">
	<sawx:expr xsi:type=`"sawx:sqlExpression`">$field1</sawx:expr>
	<sawx:expr xsi:type=`"xsd:date`">$value1</sawx:expr>
</sawx:expr>
"@
# Do double-quotes within the multi-line string have to be escaped with a back-tick???

# Apply URL-encoding...
$Encode = [uri]::EscapeDataString($filter_template)

#--------------------------------------------------------------------------------
# Run report and send output to temporary file
$temp_filename = "$temp\temp.csv"
$filter = $Encode
$flag = run_report_and_output_to_csv  $apikey  $report_path  $temp_filename  $filter

if ($flag) {
   # Copy temporary file to output file
   $output_filename = "$temp\alma-$report_name-$calendar_year$month_number`.csv"
   
   write-host $temp_filename
   write-host $output_filename
   
   copy_with_new_header_line  $temp_filename  $output_filename  $original_header_line  $new_header_line
   return $true
}else{
   # if run_report_and_output_to_csv raises an exception, temp file either does
   # not exist or was created but is incomplete.  Need to skip the Copy section below
   # and move on to the next report.
   Write-Host "No data written to permanent storage."
   return $false
}

}



