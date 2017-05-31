<div class="tab-pane fade" role="tabpanel" id="scap-below-90" aria-labelledby="scap-below-90-tab"> 
	<p>
		<div class="panel panel-primary">
			<div class="panel-heading">
				<h3 class="panel-title">SCAP Score below 90%</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="scapBelow90Tab">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#scapBelow90Tab tr td input').trigger('click')" </th>
							<th>#</th>
							<th>Benchmark</th>
							<th>Version/Release</th>
							<th>Hostname</th>
							<th>Scan Date</th>
							<th>Score</th>
						</tr>
					</thead>
					<tbody>
						{{scapBelow90}}
					</tbody>
				</table>
			</div>
		</div>
	</p> 
</div>