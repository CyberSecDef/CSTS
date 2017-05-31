<div class="tab-pane fade" role="tabpanel" id="host-mismatch" aria-labelledby="host-mismatch-tab"> 
	<p>
	
		<div class="panel panel-danger">
			<div class="panel-heading">
				<h3 class="panel-title">Missing Credentialed Scans that are Flagged as Required</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="acasReqCredMiss">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#acasReqCredMiss tr td input').trigger('click')" </th>
							<th>Host</th>
							<th>IP</th>
							<th>Manufacturer</th>
							<th>Model</th>
							<th>Firmware</th>
						</tr>
					</thead>
					<tbody>
						{{acasReqCredMissRows}}
					</tbody>
				</table>
			</div>
		</div>
		
		<div class="panel panel-danger">
			<div class="panel-heading">
				<h3 class="panel-title">Hosts in Package Missing ACAS Scans</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="missinAcasHosts">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#missinAcasHosts tr td input').trigger('click')" </th>
							<th>#</th>
							<th>Hostname</th>
							<th>IP</th>
							<th>Manufacturer</th>
							<th>Model</th>
							<th>Firmware</th>
						</tr>
					</thead>
					<tbody>
						{{missingAcasHosts}}
					</tbody>
				</table>
			</div>
		</div>
		
		<div class="panel panel-warning">
			<div class="panel-heading">
				<h3 class="panel-title">Extra Hosts</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="extraAcasHosts">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#extraAcasHosts tr td input').trigger('click')" </th>
							<th>#</th>
							<th>File Name</th>
							<th>Policy</th>
							<th>Scan Date</th>
							<th>Hostname</th>
							<th>IP</th>
						</tr>
					</thead>
					<tbody>
						{{extraAcasHosts}}
					</tbody>
				</table>
			</div>
		</div>
		
		
		
		<div class="panel panel-info">
			<div class="panel-heading">
				<h3 class="panel-title">Duplicate Hosts</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="duplicateAcasHosts">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#duplicateAcasHosts tr td input').trigger('click')" </th>
							<th>#</th>
							<th>Hostname</th>
							<th>IP</th>
							<th>Manufacturer</th>
							<th>Model</th>
							<th>Scan</th>
						</tr>
					</thead>
					<tbody>
						{{duplicateAcasHosts}}
					</tbody>
				</table>
			</div>
		</div>
		
		
	</p> 
</div> 