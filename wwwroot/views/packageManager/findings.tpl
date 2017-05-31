<h1 class="page-header">Findings</h1>
<div class="col-sm-12 col-md-12 main">
	
		<p>
			<table class="table table-striped sortable" id="findAllTab">
				<thead>
					<tr>
						
						<th id="idCol1" class="col-md-1">Scan Type</th>
						<th id="idCol2" class="col-md-1">IA Control</th>
						<th id="idCol3" class="col-md-4">Title</th>
						<th id="idCol4" class="col-md-2">Threats</th>
						<th id="idCol5" class="col-md-1">Raw Risk</th>
						<th id="idCol6" class="col-md-2">Status</th>
					</tr>
				</thead>
				<tbody>
$( $vars.acasFindings | % {
"
<tr data-status='$($_.status)'> 
	<td>ACAS</td> 
	<td>$($_.iaControl)</td> 
	<td>
		<a href=""#"" onclick=""client.findings.getData('$($_.id)');"">
		$($_.riskStatement)
		</a>
	</td>
	<td>Plugin ID: $($_.pluginId)</td>
	<td>$($_.rawRisk)</td>
	<td>$($_.status)</td>
</tr> 
"
	}
)

$( $vars.cklFindings | % {
"
<tr data-status='$($_.status)'> 
	<td>CKL</td> 
	<td>$($_.iaControl)</td> 
	<td>Group: $($_.group)</td>
	<td>Vuln ID: $($_.vulnId)<br />Rule ID: $($_.ruleId)</td>
	<td>$( $utils.GetTitleCase($_.rawRisk) )</td>
	<td>$(
		switch( $_.status){
			'NotAFinding' 	{"Completed"}
			'Not_Reviewed' 	{"Unknown"}
			'Not_Applicable'{"Not Applicable"}
			'Open' 			{"Ongoing"}
			default 		{"Ongoing"}
		}
	)</td>
</tr> 
"
	}
)

$( $vars.scapFindings | % {
"
<tr data-status='$($_.status)'> 
	<td>SCAP</td> 
	<td>$($_.iaControl)</td> 
	<td>Group: $($_.group)</td>
	<td>Vuln ID: $($_.vulnId)<br />Rule ID: $($_.ruleId)</td>
	<td>$( $utils.GetTitleCase($_.rawRisk) )</td>
	<td>$(
	if( ($_.assets.asset | ? { $_.status -eq 'Ongoing' } ) -ne $null ){
		'Ongoing'
	}else{
		'Completed'
	}
	)</td>
</tr> 
"
	}
)


				</tbody>
			</table>
			<div id="jqGridPager"></div>
		</p> 
	
</div>


<script>


	csts.onLoad( function(){
		csts.setHeader("Package Manager - <span id='package'>{{package}}</span> - Findings");
		jQuery('[data-toggle="tooltip"]').tooltip();
		
		jQuery("table#findAllTab tbody tr[data-status='Completed'], table#findAllTab tbody tr[data-status='NotAFinding']").hide();

		jQuery.support.cors = true;
		
	});
	
	
	client.findings = {
		getData : function(findingId){
			alert(findingId);
			jQuery.ajax({
				type: "GET",
				url: "{{pwd}}/packages/{{package}}/findings.xml",
				dataType: "xml",
				success: function(xml){
					alert('test');
					jQuery(xml).find("finding[id='']").each(function(){
						alert(jQuery(this).pluginId.text());
					})
				},
				error: function(jqXHR, textStatus, errorThrown) {
					alert(textStatus);
					alert(errorThrown);
				}
			});
		}
	}
	
	
</script>	