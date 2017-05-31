<div class="tab-pane fade" role="tabpanel" id="scap-open-ckl-closed" aria-labelledby="scap-open-ckl-closed-tab"> 
	<p>
		<div class="panel panel-primary">
			<div class="panel-heading">
				<h3 class="panel-title">Open SCAP Findings with Closed CKL Results</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="scapOpenCklClosed">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#scapOpenCklClosed tr td input').trigger('click')" </th>
							<th>STIG</th>
							<th>Filename</th>	
							<th>Group</th>
							<th>VulnId</th>
							<th>RuleId</th>
						</tr>
					</thead>
					<tbody>
						{{scapOpenCklClosed}}
					</tbody>
				</table>
			</div>
		</div>
	</p> 
</div>