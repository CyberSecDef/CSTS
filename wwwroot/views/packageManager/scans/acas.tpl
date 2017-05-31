<h1 class="page-header">ACAS Scans</h1>
<div class="col-sm-12 col-md-12 main">
	<div class="table-responsive">
		<button class="btn btn-primary" id="scans_reload_acas_button">Reload Scan Data</button>
		<button class="btn btn-danger" id="scans_remove_acas_button">Remove Scan</button>
		
		<table class="table table-striped" id="acasScan">
			<thead>
			<tr>
				<th><input type="checkbox" onclick="jQuery('table#acasScan tr td input').trigger('click')" </th>
				<th>#</th>
				<th>File Name</th>
				<th>Policy</th>
				<th>Scan Date</th>
				<th>Host Count</th>
				<th>Host Names</th>
			</tr>
			</thead>
			<tbody>
				{{acasScanList}}
			</tbody>
		</table>
	</div>
</div>

<script>
	csts.onLoad( function(){jQuery('div.navbar-header a.navbar-brand').html("Package Manager - <span id='package'>{{package}}</span> - ACAS Scans")} );
</script>	