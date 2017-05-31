<div class="tab-pane fade" role="tabpanel" id="old-acas-scans" aria-labelledby="old-acas-scans-tab"> 
	<p>
		<div class="panel panel-primary">
			<div class="panel-heading">
				<h3 class="panel-title">Scans Older Than 30 days</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="acasOldScan30">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#acasOldScan30 tr td input').trigger('click')" </th>
							<th>#</th>
							<th>File Name</th>
							<th>Policy</th>
							<th>Scan Date</th>
							<th>Host Count</th>
						</tr>
					</thead>
					<tbody>
						{{acasOldScan30}}
					</tbody>
				</table>
			</div>
		</div>
	
		<div class="panel panel-info">
			<div class="panel-heading">
				<h3 class="panel-title">Scans Older Than 45 days</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="acasOldScan45">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#acasOldScan45 tr td input').trigger('click')" </th>
							<th>#</th>
							<th>File Name</th>
							<th>Policy</th>
							<th>Scan Date</th>
							<th>Host Count</th>
							
						</tr>
					</thead>
					<tbody>
						{{acasOldScan45}}
					</tbody>
				</table>
			</div>
		</div>						
	
		<div class="panel panel-warning ">
			<div class="panel-heading">
				<h3 class="panel-title">Scans Older Than 60 days</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="acasOldScan60">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#acasOldScan60 tr td input').trigger('click')" </th>
							<th>#</th>
							<th>File Name</th>
							<th>Policy</th>
							<th>Scan Date</th>
							<th>Host Count</th>
							
						</tr>
					</thead>
					<tbody>
						{{acasOldScan60}}
					</tbody>
				</table>
			</div>
		</div>
		
		<div class="panel panel-danger">
			<div class="panel-heading">
				<h3 class="panel-title">Scans Older Than 90 days</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="acasOldScan90">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#acasOldScan90 tr td input').trigger('click')" </th>
							<th>#</th>
							<th>File Name</th>
							<th>Policy</th>
							<th>Scan Date</th>
							<th>Host Count</th>
							
						</tr>
					</thead>
					<tbody>
						{{acasOldScan90}}
					</tbody>
				</table>
			</div>
		</div>
	</p> 
</div>