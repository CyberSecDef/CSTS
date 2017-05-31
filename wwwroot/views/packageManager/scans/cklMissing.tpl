<div class="tab-pane fade" role="tabpanel" id="missing-ckl" aria-labelledby="old-ckl-tab"> 
	<p>
		<div class="panel panel-danger">
			<div class="panel-heading">
				<h3 class="panel-title">Required CKLs that are Missing</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="cklMissing">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#cklOldScan90 tr td input').trigger('click')" </th>
							<th>STIG</th>
							<th>Version</th>
							<th>Release</th>
						</tr>
					</thead>
					<tbody>
						{{cklMissingRows}}
					</tbody>
				</table>
			</div>
		</div>
	</p> 
</div>