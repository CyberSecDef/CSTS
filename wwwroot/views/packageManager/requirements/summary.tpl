<div class="tab-pane " role="tabpanel" id="req-summary" aria-labelledby="req-summary-tab"> 
	<p>
		<div class="panel panel-primary">
			<div class="panel-heading">
				<h3 class="panel-title">Requirements Summary</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="reqSummaryTab">
					<thead>
						<tr>
							<th class="col-md-1"><input type="checkbox" onclick="jQuery('table#reqSummaryTab tr td input').trigger('click')" </th>
							<th class="col-md-1">Scan Type</th>
							<th class="col-md-3">Title</th>
							<th class="col-md-1">Version</th>
							<th class="col-md-1">Release</th>
							<th class="col-md-4">Hosts</th>
						</tr>
					</thead>
					<tbody>
						{{reqSummaryTab}}
					</tbody>
				</table>
			</div>
		</div>
	</p> 
</div>