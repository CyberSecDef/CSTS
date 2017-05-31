<div class="tab-pane fade" role="tabpanel" id="ckl-not-rev" aria-labelledby="ckl-not-rev-tab"> 
	<p>
		<div class="panel panel-primary">
			<div class="panel-heading">
				<h3 class="panel-title">Checklists with Requirements Not Reviewed</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="cklReqNotRevTab">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#cklReqNotRevTab tr td input').trigger('click')" </th>
							<th>#</th>
							<th>STIG</th>
							<th>Version/Release</th>
							<th>Scan Date</th>
							<th>Filename</th>
							<th>Number Not Reviewed</th>
						</tr>
					</thead>
					<tbody>
						{{cklReqNotRev}}
					</tbody>
				</table>
			</div>
		</div>
	</p> 
</div>