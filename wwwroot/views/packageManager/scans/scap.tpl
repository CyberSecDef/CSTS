<h1 class="page-header">SCAP Scans</h1>
<div class="col-sm-12 col-md-12 main">
	<div class="table-responsive">
		<button class="btn btn-primary" id="scans_reload_scap_button">Reload Scan Data</button>
		<button class="btn btn-danger" id="scans_remove_scap_button">Remove Scan</button>
		
		<table class="table table-striped" id="scapScan">
			<thead>
			<tr>
				<th><input type="checkbox" onclick="jQuery('table#scapScan tr td input').trigger('click')" </th>
				<th>#</th>
				<th>Benchmark</th>
				<th>Version/Release</th>
				<th>Host Count</th>
				<th>Host Names</th>
			</tr>
			</thead>
			<tbody>
				{{scapScanList}}
			</tbody>
		</table>
	</div>
</div>

<script>
	csts.onLoad(function(){
		csts.setHeader("Package Manager - <span id='package'>{{package}}</span> - SCAP Scans");
		jQuery('[data-toggle="tooltip"]').tooltip();
	});
</script>	