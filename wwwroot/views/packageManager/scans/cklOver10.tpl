<div class="tab-pane fade" role="tabpanel" id="ckl-over-10" aria-labelledby="ckl-over-10-tab"> 
	<p>
		<div class="panel panel-primary">
			<div class="panel-heading">
				<h3 class="panel-title">Checklist with over 10% Failed Requirements</h3>
			</div>
			<div class="panel-body">
				<table class="table table-striped" id="cklOver10Tab">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#cklOver10Tab tr td input').trigger('click')" </th>
							<th>#</th>
							<th>Scan Date</th>
							<th>Filename</th>
							<th>Ongoing</th>
							<th>Not Reviewed</th>
							<th>Not A Finding</th>
							<th>Not Applicable</th>
							<th>Total Requirements</th>
						</tr>
					</thead>
					<tbody>
						{{cklOver10}}
					</tbody>
				</table>
			</div>
		</div>
	</p> 
</div>