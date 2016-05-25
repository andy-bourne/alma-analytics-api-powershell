#--------------------------------------------------------------------------------
# Dependencies
. .\alma_analytics_API_run_snapshot_report.ps1			# run_snapshot_report

#--------------------------------------------------------------------------------
function current_users ($config, $apikey, $calendar_year_and_month) {
	# Run current users report
	write-host "current_users"

	#--------------------------------------------------------------------------------
	$temp = $config["temp_data_location"];

	#--------------------------------------------------------------------------------
	$report_name = "current_users"
	$report_path =  "%2Fshared%2FSalford University%2FReports%2FFulfillment%2FCirculation Coordinator%2Fwork_in_progress_current_users_given_cutoff_date_andy_bourne"
	$original_header_line = '"Column0","Column1","Column2","Column3","Column4","Column5"'

	$new_header_line = '"dummy","department_name","expiry_date","username","user_group_code","user_group_name"'

	$calendar_year = $calendar_year_and_month.Substring(0,4) # e.g. 201601 -> 2016
	$month_number  = $calendar_year_and_month.Substring(4,2) # e.g. 201601 -> 01
	$retcode = run_snapshot_report  $apikey  $report_name  $report_path  $original_header_line  $new_header_line  $calendar_year  $month_number  $temp
	# get current users - e.g. if run for calendar year month 201601, we run the script shortly after 31/01/2016
	# and the script runs an alma analytics report with a cut-off date of 01/01/2016, i.e. it only selects users
	# where expiry date >= 2016-01-01
	# Sample record: "0","Academic Division","2016-03-22","ABC04018","EXT","External Borrower"
	
	return $retcode		# $true/$false
}

#--------------------------------------------------------------------------------
[string]$private:calendar_year_and_month = "201601"

#--------------------------------------------------------------------------------
# Set apikey
$private:apikey = "************************************"

#--------------------------------------------------------------------------------
# Get configuration settings
# Keys: "temp_data_location" [and possibly others in a full application]
$private:config = @{};
Import-Csv ".\config.csv" | 
% { $config[$_.key] = $_.value }

#--------------------------------------------------------------------------------
# Run the report
$retcode = current_users	$config  $apikey  $calendar_year_and_month
if ($retcode) {
	write-host "Successful"
	# The output file is in the directory identified by the "temp_data_location" key in .\config.csv
	# The output filename is "alma-current_users-201601.csv"
} else {
	write-host "Failed"
}

#--------------------------------------------------------------------------------
