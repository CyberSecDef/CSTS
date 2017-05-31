<div class="tab-pane fade" role="tabpanel" id="scap-host-mismatch" aria-labelledby="scap-host-mismatch-tab"> 
	<p>
		<div class="panel panel-danger">
			<div class="panel-heading">
				<h3 class="panel-title">Missing SCAP Scans Flagged as Required</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="scapMissingScans">
					<thead>
						<tr>
							<th class="col-md-1"><input type="checkbox" onclick="jQuery('table#scapMissingScans tr td input').trigger('click')" </th>
							<th class="col-md-3">Title</th>
							<th class="col-md-1">Version</th>
							<th class="col-md-1">Release</th>
							<th class="col-md-6">Host</th>
						</tr>
					</thead>
					<tbody>
						{{missingScapScans}}
					</tbody>
				</table>
			</div>
		</div>
		
		
		<div class="panel panel-warning">
			<div class="panel-heading">
				<h3 class="panel-title">Extra Hosts</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="extraScapHosts">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#extraScapHosts tr td input').trigger('click')" </th>
							<th>#</th>
							<th>Benchmark</th>
							<th>Version/Release</th>
							<th>Hostname</th>
							<th>Scan Date</th>
							<th>Score</th>
						</tr>
					</thead>
					<tbody>
						{{extraScapHosts}}
					</tbody>
				</table>
			</div>
		</div>
		
		<div class="panel panel-info">
			<div class="panel-heading">
				<h3 class="panel-title">Duplicate Hosts</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="duplicateScapHosts">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#duplicateScapHosts tr td input').trigger('click')" </th>
							<th>#</th>
							<th>Benchmark</th>
							<th>Version/Release</th>
							<th>Hostname</th>
						</tr>
					</thead>
					<tbody>
						{{duplicateScapHosts}}
					</tbody>
				</table>
			</div>
		</div>
		
		
		
	</p> 
</div> 