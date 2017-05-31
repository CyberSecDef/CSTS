<div class="tab-pane fade" role="tabpanel" id="scap-no-ckl" aria-labelledby="scap-no-ckl-tab"> 
	<p>
		<div class="panel panel-primary">
			<div class="panel-heading">
				<h3 class="panel-title">SCAP Run With No CKL</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="scapNoCklTab">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#scapNoCklTab tr td input').trigger('click')" </th>
							<th>#</th>
							<th>Benchmark</th>
							<th>Version/Release</th>
							<th>Hostname</th>
							<th>Scan Date</th>
							<th>Score</th>
						</tr>
					</thead>
					<tbody>
						{{scapNoCkl}}
					</tbody>
				</table>
			</div>
		</div>
	</p> 
</div>