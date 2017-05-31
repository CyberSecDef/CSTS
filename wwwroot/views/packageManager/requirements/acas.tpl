<div class="tab-pane fade" role="tabpanel" id="req-acas" aria-labelledby="req-acas-tab"> 
	<p>
		<div class="panel panel-primary">
			<div class="panel-heading">
				<div class="row">
					<div class="col-md-6">
						<h3 class="panel-title">ACAS Requirements</h3>
					</div>
					<div class="col-md-6">
						<button class="btn btn-info btn-xs pull-right" onClick="client.requirements.acas.checkCredentialed();">Credentialed Required</button>
						<button class="btn btn-info btn-xs pull-right" onClick="client.requirements.acas.checkRequired();">Scan Required</button>&nbsp;
						
					</div>
				</div>
			</div>
			<div class="panel-body">
				<table class="table table-striped sortable" id="reqAcasTab">
					<thead>
						<tr>
							<th><input type="checkbox" onclick="jQuery('table#reqAcasTab tr td input.asset_checkbox').trigger('click')" </th>
							<th>Hostname</th>
							<th>IP</th>
							<th>Scan Required?</th>
							<th>Credentialed?</th>
						</tr>
					</thead>
					<tbody>
						{{reqAcasTab}}
					</tbody>
				</table>
			</div>
		</div>
	</p> 
</div>

<script>
	csts.onLoad(function(){
		jQuery('[data-toggle="tooltip"]').tooltip();
		jQuery("[name='acas_scan_req']").bootstrapSwitch();
		jQuery("[name='acas_cred_req']").bootstrapSwitch();
	});
	client.requirements = client.requirements || {};
	client.requirements.acas = {
		checkRequired : function(){
			jQuery("input.acas_scan_req[type='checkbox']").bootstrapSwitch('state', true, true);
		},
		checkCredentialed : function(){
			jQuery("input.acas_cred_req[type='checkbox']").bootstrapSwitch('state', true, true);
		}
	}
</script>	