<div class="tab-pane fade" role="tabpanel" id="old-scap-scans" aria-labelledby="old-scap-scans-tab"> 
	<p>
		<div class="panel panel-primary">
			<div class="panel-heading">
				<h3 class="panel-title">SCAP Scans Older Than 30 days</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="scapOldScan30">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#scapOldScan30 tr td input').trigger('click')" </th>
							<th>#</th>
							<th>Benchmark</th>
							<th>Version/Release</th>	
							<th>Hostname</th>
							<th>Scan Date</th>
							<th>Score</th>
						</tr>
					</thead>
					<tbody>
						{{scapOldScan30}}
					</tbody>
				</table>
			</div>
		</div>
	
		<div class="panel panel-info">
			<div class="panel-heading">
				<h3 class="panel-title">SCAP Scans Older Than 45 days</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="scapOldScan45">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#scapOldScan45 tr td input').trigger('click')" </th>
							<th>#</th>
							<th>Benchmark</th>
							<th>Version/Release</th>	
							<th>Hostname</th>
							<th>Scan Date</th>
							<th>Score</th>
						</tr>
					</thead>
					<tbody>
						{{scapOldScan45}}
					</tbody>
				</table>
			</div>
		</div>						
	
		<div class="panel panel-warning ">
			<div class="panel-heading">
				<h3 class="panel-title">SCAP Scans Older Than 60 days</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="scapOldScan60">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#scapOldScan60 tr td input').trigger('click')" </th>
							<th>#</th>
							<th>Benchmark</th>
							<th>Version/Release</th>	
							<th>Hostname</th>
							<th>Scan Date</th>
							<th>Score</th>
						</tr>
					</thead>
					<tbody>
						{{scapOldScan60}}
					</tbody>
				</table>
			</div>
		</div>
		
		<div class="panel panel-danger">
			<div class="panel-heading">
				<h3 class="panel-title">SCAP Scans Older Than 90 days</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="scapOldScan90">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#scapOldScan90 tr td input').trigger('click')" </th>
							<th>#</th>
							<th>Benchmark</th>
							<th>Version/Release</th>	
							<th>Hostname</th>
							<th>Scan Date</th>
							<th>Score</th>
						</tr>
					</thead>
					<tbody>
						{{scapOldScan90}}
					</tbody>
				</table>
			</div>
		</div>
	</p> 
</div>