<h1 class="page-header">CKL Scans</h1>
<div class="col-sm-12 col-md-12 main">
	<div class="table-responsive">
		<button class="btn btn-primary" id="scans_reload_ckl_button">Reload Ckl Data</button>
		<button class="btn btn-danger" id="scans_remove_ckl_button">Remove Ckl</button>
		
		<table class="table table-striped" id="cklScan">
			<thead>
			<tr>
				<th><input type="checkbox" onclick="jQuery('table#cklScan tr td input').trigger('click')" </th>
				<th>#</th>
				<th>STIG</th>
				<th>Version/Release</th>
				<th>Ongoing</th>
				<th>Not a Finding</th>
				<th>Not Applicable</th>
				<th>Not Reviewed</th>
			</tr>
			</thead>
			<tbody>
				{{cklScanList}}
			</tbody>
		</table>
	</div>
</div>


<script>
	csts.onLoad(function(){
		csts.setHeader("Package Manager - <span id='package'>{{package}}</span> - STIG Checklists");
		jQuery('[data-toggle="tooltip"]').tooltip();
	});
</script>	