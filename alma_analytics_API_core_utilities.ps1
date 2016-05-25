#====================================================================================================
function get_data_from_Alma_Analytics_API_web_service( $apikey, $report_path, $resumption_token, $limit, $filter){
#				Call with either:
#				(a) report_path specified and resumption_token null - for 1st batch of results
#				(b) resumption_token specified [and report_path null] - for subsequent batches of results
#				Other params:
#				- apikey			[A key assigned by the local Alma administrator to give read-only access to Production Alma]
#									Note: the API hosting platform can determine the institution from the value of the API key.
#										  It can also determine from the key that read-only access is intended, and that we are
#										  connecting to the Production instance of Alma as opposed to the Sandbox instance
#										  (Alma Analytics is connected to Production Alma only - there is no "Sandbox" instance
#										  of Analytics).
#				- $limit			[Max number of records in a batch - a multiple of 25 - in the range 25-1000]
#               - $filter			[a filter expression - URL-encoded version of an OBIEE filter expression]
#                                   Note: only needed on 1st call - not needed on subsequent 'resumption' calls
#				Returns an object with attributes:
#				- Success			[$true or $false]
#				- ResumptionToken	[Returns a value when 1st batch of results is retrieved, null for subsequent batches]
#				- IsFinished 		[True or False, as string]
#				- Row				[Array of row objects]
#				The Resumption token delivered by the first call of the function is passed as a parameter on
#				subsequent calls of the function for the same report.
#				To get the entire result set for the report, call the function repeatedly until IsFinished is set to "true".
#				The attributes of a row object are called Column0, Column1, Column2, etc
#				The number of columns and their meaning depends on which specific Alma Analytics report is invoked
#				by the first call of the function (determined by the $report_path parameter).
#				Ref:
#				https://developers.exlibrisgroup.com/blog/Working-with-Analytics-REST-APIs
#
#				NEXT: 
#					- need to think about error handling - e.g. 
#						- API service temp unavilable, 
#						- $report_path does not exist etc
#						- invalid api key
#						- timeout
#						- HTTP 400
#						- HTTP 403 Forbidden - there is an actual XML response payload
#						- HTTP 500
#					- maybe, just before returning $return_object, we try to set $return_object.NumberOfRows to be equal to
#					  $return_object.Row.Length - make $return_object.NumberOfRows zero (or undefined?) if $return_object.Row
#					  is undefined? - and if so, set $return_object.errors_exist/error_code/error_message attributes.

if ($resumption_token -eq $null){
   $rest_url = "https://api-eu.hosted.exlibrisgroup.com/almaws/v1/analytics/reports?path=$report_path&apikey=$apikey&limit=$limit&filter=$filter"
   write-host "GET $rest_url"
}else{
   $rest_url = "https://api-eu.hosted.exlibrisgroup.com/almaws/v1/analytics/reports?token=$resumption_token&apikey=$apikey&limit=$limit"
   write-host "GET $rest_url"
}

$retcode = $null
$retdesc = $null
$rethdr  = $null
$content = $null

try {
  $response = Invoke-WebRequest -uri $rest_url

  # response object has methods/attribs that include
  # *** string Content {get;} 
  # *** System.Collections.Generic.Dictionary[string,string] Headers {get;} 
  # *** int StatusCode {get;} 
  # *** string StatusDescription {get;}
  
  $retcode = $response.StatusCode			# Normally 200
  $retdesc = $response.StatusDescription	# Normally "OK"
  $rethdr  = $response.Headers
  
  # rethdr example
  # [Access-Control-Allow-Origin, *]
  # [Access-Control-Allow-Methods, GET,OPTIONS] 
  # [Access-Control-Allow-Headers, Origin, X-Requested-With, Content-Type, Accept] 
  # [P3P, CP="IDC DSP COR ADM DEVi TAIi PSA PSD IVAi IVDi CONi HIS OUR IND CNT"] 
  # [Set-Cookie, ADRUM_BTa="R:0|g:5f73745f-db8b-4f61-9890-f2862fed5cf4"; Version=1; Domain=api-eu.hosted.exlibrisgroup.com; Max-Age=30; Expires=Tue, 15-Dec-2015 23:03:38 GMT; Path=/almaws/v1/analytics,JSESSIONID="A77ED88C8260AD153366309C74E30972.app01.eu00.prod.alma.dc03.hosted.exlibrisgroup.com:1801"; Version=1; Domain=api-eu.hosted.exlibrisgroup.com; Path=/almaws/v1/analytics,ADRUM_BT1="R:0|i:1340310"; Version=1; Domain=api-eu.hosted.exlibrisgroup.com; Max-Age=30; Expires=Tue, 15-Dec-2015 23:03:38 GMT; Path=/almaws/v1/analytics,ADRUM_BTs="R:0|s:f"; Version=1; Domain=api-eu.hosted.exlibrisgroup.com; Max-Age=30; Expires=Tue, 15-Dec-2015 23:03:38 GMT; Path=/almaws/v1/analytics,sto-id-%3FAlma_Prod%3FappX-1801.eu00.prod.alma-sg=DPDIBAAK; Domain=api-eu.hosted.exlibrisgroup.com; Expires=Fri, 12-Dec-2025 23:03:06 GMT; Path=/almaws/v1/analytics] 
  # [Server, Apache-Coyote/1.1] 
  # [Content-Type, application/xml;charset=UTF-8] 
  # [Content-Length, 314] 
  # [Date, Tue, 15 Dec 2015 23:03:08 GMT]
  
  $content_type = $rethdr["Content-Type"]		# application/xml;charset=UTF-8   OR   
  $content_length = $rethdr["Content-Length"]	# Weirdly, this is set when data_chunk.Row is null, but not set when data_chunk.Row is defined

  Write-Host "retcode = $retcode  |  retdesc = $retdesc  |  content_type = $content_type"
  
  $content = $response.Content
  [xml]$xml = $content				# $content has type "string"; $xml has type "xml"
  
  $Success = $true
  $ResumptionToken = $xml.report.QueryResult.ResumptionToken
  $IsFinished = $xml.report.QueryResult.IsFinished
  $Row = $xml.report.QueryResult.ResultXml.rowset.Row

  $return_object = [pscustomobject]@{Success=$null; ResumptionToken=$null; IsFinished=$null; Row=$null; HttpRetcode=$null; ApiErrorCode=$null; ApiErrorMessage=$null}
  $return_object.Success = $Success
  $return_object.ResumptionToken = $ResumptionToken
  $return_object.IsFinished = $IsFinished
  $return_object.Row = $Row
  $return_object.HttpRetcode = $retcode

} catch {

  #ref https://msdn.microsoft.com/en-us/library/ms714465(v=vs.85).aspx - powershell error record

  #--------------------------------------------------------------------------------
  $retcode = $_.Exception.Response.StatusCode.Value__			# Have observed: 400, 500
  $retdesc = $_.Exception.Response.StatusDescription.Value__
  $rethdr  = $_.Exception.Response.Headers.Value__
  #Write-Host "get excp... retcode = $retcode"
  #Write-Host "get excp... retdesc = $retdesc"

  #--------------------------------------------------------------------------------
  #Write-Host $_.ToString()
  # Have observed: Invalid API Key
  # Have observed: The remote name could not be resolved: 'api-eu.hosted.exlibrisgroup.com' 	[no network connection]
  
  $my_err_msg = $_.ToString()
  if ( $my_err_msg -eq "Invalid API Key") {
	Write-Host "get excp... `$_.ToString() really is 'Invalid API Key'"
    $return_object = [pscustomobject]@{Success=$null; ResumptionToken=$null; IsFinished=$null; Row=$null; HttpRetcode=$null}
    $return_object.Success = $false
    $return_object.HttpRetcode = $retcode
	#if $retcode is null then pass back string "Invalid API Key"
    return $return_object

	#TODO - add "Invalid API Key" to the return object (maybe as "ErrorCode" attrib as opposed to "ApiErrorCode"? Or maybe in same attrib?)
  }
  if ( $my_err_msg.StartsWith("The remote name could not be resolved:") ) {
    #Note: actually need to check that $my_err_msg starts with "The remote name could not be resolved:" - not -eq
	Write-Host "get excp... `$_.ToString() really starts with 'The remote name could not be resolved:'"
	Write-Host "NO NETWORK CONNECTION"
    $return_object = [pscustomobject]@{Success=$null; ResumptionToken=$null; IsFinished=$null; Row=$null; HttpRetcode=$null}
    $return_object.Success = $false
    $return_object.HttpRetcode = $retcode
	#if $retcode is null then pass back string "The remote name could not be resolved:" or "no network connection"
    return $return_object
	
	#TODO - add "NO NETWORK CONNECTION" to the return object (maybe as "ErrorCode" attrib as opposed to "ApiErrorCode"? Or maybe in same attrib?)
  }
  
 #Have observed
 #<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
 #<web_service_result xmlns="http://com/exlibris/urm/general/xmlbeans">
 #	<errorsExist>true</errorsExist>
 #	<errorList>
 #		<error>
 #			<errorCode>INTERNAL_SERVER_ERROR</errorCode>
 #			<errorMessage>
 #				Path not found 
 #				(/shared/Salford University/Reports/Fulfillment/Circulation Stats/
 #				work_in_progress_current_users_given_cutoff_date_andy_bourne)
 #			</errorMessage>
 #			<trackingId>E01-0205174410-EXN2H-AWAE1222833830</trackingId>
 #		</error>
 #	</errorList>
 #</web_service_result>
 # - when retcode was 500
 
 #Have observed
 #<web_service_result xmlns="http://com/exlibris/urm/general/xmlbeans">
 #	<errorsExist>true</errorsExist>
 #	<errorList>
 #		<error>
 #			<errorCode>GENERAL_ERROR</errorCode>
 #			<errorMessage>A Gateway error has occurred - Make sure you add an appropriate apikey as a parameter or a header.</errorMessage>
 #		</error>
 #	</errorList>
 #</web_service_result>
 #- if API is called without an apikey
 
  [xml]$xml = $_
  $ApiErrorCode = $xml.web_service_result.errorList.error.errorCode
  $ApiErrorMessage = $xml.web_service_result.errorList.error.errorMessage
 
  #--------------------------------------------------------------------------------
  $exception = $_.Exception
  #$my_type = $exception.GetType() - Have observed: System.Net.WebException
  #$exception has many attribs/methods but the only significant ones seem to be
  #**** string ToString(), 
  #**** System.Net.WebResponse Response {get;} 

  #--------------------------------------------------------------------------------
  $response = $_.Exception.Response

  #--------------------------------------------------------------------------------
  $return_object = [pscustomobject]@{Success=$null; ResumptionToken=$null; IsFinished=$null; Row=$null; HttpRetcode=$null; ApiErrorCode=$null; ApiErrorMessage=$null}
  $return_object.Success = $false
  $return_object.HttpRetcode = $retcode
  $return_object.ApiErrorCode=$ApiErrorCode
  $return_object.ApiErrorMessage=$ApiErrorMessage
}

$return_object
}

#====================================================================================================
function run_report_and_output_to_csv ($apikey, $report_path, $output_filename, $filter) {
#
#				Parameters:
#				- apikey			[A key assigned by the local Alma administrator to give read-only access to Production Alma]
#									Note: the API hosting platform can determine the institution from the value of the API key.
#										  It can also determine from the key that read-only access is intended, and that we are
#										  connecting to the Production instance of Alma as opposed to the Sandbox instance
#										  (Alma Analytics is connected to Production Alma only - there is no "Sandbox" instance
#										  of Analytics).
#				- report_path
#				- output_filename
#               - $filter			[a filter expression - URL-encoded version of an OBIEE filter expression]
#
#				Returns:
#				- $true				if we are returning because the output is complete
#				- $false			if we are returning because $data_chunk.Success -eq $false 
#									which indicates that the output is incomplete,
#									so we don't want to permanently save the output file
#
#				MODS -
#				- deal with the situation where we are not getting $data_chunk.Success -eq $false but where we have a sequence of calls that return 
#				"data_chunk.Row is null".  If we get a sequence of, say, 3 instances of "data_chunk.Row is null", we introduce a delay of, say 1 sec
#				in each pass of the loop.  After another 3 instances, increase time delay to 2 secs.  After another 3, 10 secs.  Continue with a 10 
#				sec loop delay - for 5 mins max.  Abandon the attempt after 5 mins (5 mins / 10 secs = 30 attempts).  If we get a succesful re-try, 
#				we reset the time delay to 0.  Next seq of 3 nulls starts the process again.
#

Write-Host "-----------------------"

# Delete the output file if it already exists
if (Test-Path "$output_filename") {
	Remove-Item $output_filename
}

$resumption_token = $null

$i=0
do {
   $data_chunk = $null
   if ($resumption_token -eq $null) {
      # resumption token is null - process first data chunk
      $data_chunk = get_data_from_Alma_Analytics_API_web_service  $apikey  $report_path  $resumption_token  1000  $filter
      $resumption_token = $data_chunk.ResumptionToken
   }else{
      # resumption token is not null - process subsequent data chunks
      $data_chunk = get_data_from_Alma_Analytics_API_web_service  $apikey  $report_path  $resumption_token  1000  $filter
   }

   if ($data_chunk -eq $null) {Write-Host "-----------------------"; return $false}
   if ($data_chunk.Success -eq $null) {Write-Host "-----------------------"; return $false}
   
   if ($data_chunk.Success -eq $false) {
#		write-host "In run_report_and_output_to_csv"
#  $return_object = [pscustomobject]@{Success=$null; ResumptionToken=$null; IsFinished=$null; Row=$null; HttpRetcode=$null; ApiErrorCode=$null; ApiErrorMessage=$null}
		$HttpRetcode = $data_chunk.HttpRetcode
		$ApiErrorCode = $data_chunk.ApiErrorCode
		$ApiErrorMessage = $data_chunk.ApiErrorMessage
		write-host "HttpRetcode - $HttpRetcode"
		write-host "ApiErrorCode - $ApiErrorCode"
		write-host "ApiErrorMessage - $ApiErrorMessage"
		Write-Host "-----------------------"; 
 		return $false
   }
	  
   # Append content of $data_chunk.Row array to csv file
   if ($data_chunk.Row -ne $null){
      $n = $data_chunk.Row.length
	  write-host "data_chunk.Row contains $n elements"
	  if ($n -eq $null) {
		  write-host "data_chunk row length is null"	#After N (N>=0) chunks of 1000, if there is then exactly 1 record remaining, $data_chunk.Row is not an array - hence length is null
		  write-host $data_chunk.Row
		  write-host $data_chunk						#@{Success=True; ResumptionToken=; IsFinished=true; Row=System.Xml.XmlElement}
		  write-host $data_chunk.Row.outerXML			#<Row xmlns="urn:schemas-microsoft-com:xml-analysis:rowset"><Column0>0</Column0><Column1>2015</Column1><Column2>4</Column2><Column3>PVP216</Column3><Column4>PGFT</Column4><Column5>1</Column5></Row>
		  write-host $data_chunk.Row.Column1			#2015
		  write-host $data_chunk.Row.Column2			#4
	  }
      $data_chunk.Row | Export-Csv $output_filename -NoTypeInformation -Append -Force
   }else{
      Write-Host "data_chunk.Row is null"
   }
   #Write-Host $data_chunk.Success
   
   if ($data_chunk.IsFinished -eq "true") {
		write-host "Page $i retrieved --- this is the last page"
   }else{
		write-host "Page $i retrieved --- this is not the last page"
   }
   $i++
}
until (  ($data_chunk.IsFinished -eq "true")  -or  ($i -gt 300)  )

Write-Host "-----------------------"; 
if ($data_chunk.IsFinished -eq "true") {
   return $true
}else{
   return $false
}

}

#====================================================================================================
function copy_with_new_header_line ($old_file_path, $new_file_path, $original_header_line, $new_header_line) {

### CSV output file has first line...
###    "Column0","Column1","Column2","Column3","Column4","Column5"
### Need to change this to
###    "skip","year","month","username","usertype","numloans" [example - will be different for different reports]
### Can do this by a filter (loop) that just copies line-by-line
### but with a change in the first line
### (all other lines to end of file are just copied as-is)

   if (Test-Path "$old_file_path") {
	  #nop
   }else{
	  Write-Host "after phase 1, temp file $old_file_path does not exist, so cannot proceed with phase 2"
	  return
   }
	write "copying to file $new_file_path"
	Get-Content  $old_file_path | 
	Foreach-Object {
	    if ($_ -eq $original_header_line) {$new_header_line} else {$_}
	} | 
	Out-File  "$new_file_path" -Encoding ascii
	#Out-File  "$new_file_path" -Encoding utf8
	#Ref: http://stackoverflow.com/questions/5596982/using-powershell-to-write-a-file-in-utf-8-without-the-bom
	return
}
#NOTE: may want to use 
#	Out-File  "$new_file_path" -Encoding "Default"
#rather than 
#	Out-File  "$new_file_path" -Encoding ascii
