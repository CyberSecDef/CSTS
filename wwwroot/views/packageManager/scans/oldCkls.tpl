<div class="tab-pane fade" role="tabpanel" id="old-ckl-scans" aria-labelledby="old-ckl-scans-tab"> 
	<p>
		<div class="panel panel-primary">
			<div class="panel-heading">
				<h3 class="panel-title">Ckls Older Than 30 days</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="cklOldScan30">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#cklOldScan30 tr td input').trigger('click')" </th>
							<th>#</th>
							<th>STIG</th>
							<th>Version/Release</th>
							<th>Scan Date</th>
							<th>Filename</th>
						</tr>
					</thead>
					<tbody>
						{{cklOldScan30}}
					</tbody>
				</table>
			</div>
		</div>
	
		<div class="panel panel-info">
			<div class="panel-heading">
				<h3 class="panel-title">Ckls Older Than 45 days</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="cklOldScan45">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#cklOldScan45 tr td input').trigger('click')" </th>
							<th>#</th>
							<th>STIG</th>
							<th>Version/Release</th>
							<th>Filename</th>
							
						</tr>
					</thead>
					<tbody>
						{{cklOldScan45}}
					</tbody>
				</table>
			</div>
		</div>						
	
		<div class="panel panel-warning ">
			<div class="panel-heading">
				<h3 class="panel-title">Ckls Older Than 60 days</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="cklOldScan60">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#cklOldScan60 tr td input').trigger('click')" </th>
							<th>#</th>
							<th>STIG</th>
							<th>Version/Release</th>
							<th>Filename</th>
							
						</tr>
					</thead>
					<tbody>
						{{cklOldScan60}}
					</tbody>
				</table>
			</div>
		</div>
		
		<div class="panel panel-danger">
			<div class="panel-heading">
				<h3 class="panel-title">Ckls Older Than 90 days</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="cklOldScan90">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#cklOldScan90 tr td input').trigger('click')" </th>
							<th>#</th>
							<th>STIG</th>
							<th>Version/Release</th>
							<th>Filename</th>
							
						</tr>
					</thead>
					<tbody>
						{{cklOldScan90}}
					</tbody>
				</table>
			</div>
		</div>
	</p> 
</div>