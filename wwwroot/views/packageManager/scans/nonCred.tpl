<div class="tab-pane fade" role="tabpanel" id="non-cred" aria-labelledby="non-cred-tab"> 
	<p>
		<div class="panel panel-primary">
			<div class="panel-heading">
				<h3 class="panel-title">Non-Credentialled Scans</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="nonCredTab">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#nonCredTab tr td input').trigger('click')" </th>
							<th>#</th>
							<th>File Name</th>
							<th>Policy</th>
							<th>Scan Date</th>
							<th>Hostname</th>
							<th>IP</th>
						</tr>
					</thead>
					<tbody>
						{{nonCred}}
					</tbody>
				</table>
			</div>
		</div>
	</p> 
</div>