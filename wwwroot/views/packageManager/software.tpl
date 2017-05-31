<h1 class="page-header">Software</h1>
<div class="col-sm-12 col-md-12 main">
	<div class="table-responsive">
		<button class="btn btn-success" data-toggle="modal" data-target="#myModal">Add Software</button>
		<button class="btn btn-danger" id="assets_remove_software_button">Remove Software</button>
		<button class="btn btn-primary" id="assets_reload_software_button">Reload Software Data From Hosts</button>
		
		<table class="table table-striped sortable exportable" id="software">
			<thead>
			<tr>
				<th><input type="checkbox" onclick="jQuery('table#software tr td input').trigger('click')" </th>
				<th>Name</th>
				<th>Version</th>
				<th>Vendor</th>
				<th>Hosts</th>
			</tr>
			</thead>
			<tbody>
				{{softwareList}}
			</tbody>
		</table>
		<hr>
		<caption>
			There are <strong>{{softwareCount}}</strong> applications in the Official <strong><u>{{Package}}</u></strong> package.
		</caption>
	</div>
</div>


<div class="modal fade" id="myModal" tabindex="-1" role="dialog" aria-labelledby="myModalLabel">
	<div class="modal-dialog" role="document">
		<div class="modal-content">
			<div class="modal-header">
				<button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
				<h4 class="modal-title" id="myModalLabel">Add Software</h4>
			</div>
			<div class="modal-body">
				
				<div class="form-group">
					<label for="addSoftware_Name">Name</label>
					<input type="text" class="form-control" id="addSoftware_Name" placeholder="Name">
				</div>
				<div class="form-group">
					<label for="addSoftware_Version">Version</label>
					<input type="text" class="form-control" id="addSoftware_Version" placeholder="1.0">
				</div>
				<div class="form-group">
					<label for="addSoftware_Vendor">Vendor</label>
					<input type="text" class="form-control" id="addSoftware_Vendor" placeholder="Vendor">
				</div>
				<div class="form-group">
					<label for="addSoftware_Hosts">Hosts</label>
					<input type="text" class="form-control" id="addSoftware_Hosts" placeholder="Hostnames">
				</div>
				
			
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
				<button type="button" class="btn btn-primary" id="assets_add_software_submit" data-dismiss="modal" >Add Software</button>
			</div>
		</div>
	</div>
</div>

<div class="modal fade" id="myEditModal" tabindex="-1" role="dialog" aria-labelledby="myModalLabel">
	<div class="modal-dialog" role="document">
		<div class="modal-content">
			<div class="modal-header">
				<button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
				<h4 class="modal-title" id="myModalLabel">Edit Software</h4>
			</div>
			<div class="modal-body">
				
			<div class="form-group">
				<label for="editSoftware_Name">Name</label>
				<input type="text" class="form-control" id="editSoftware_Name" placeholder="Name">
			</div>
			<div class="form-group">
				<label for="editSoftware_Version">Version</label>
				<input type="text" class="form-control" id="editSoftware_Version" placeholder="1.0">
			</div>
			<div class="form-group">
				<label for="editSoftware_Vendor">Vendor</label>
				<input type="text" class="form-control" id="editSoftware_Vendor" placeholder="Vendor">
			</div>
			<div class="form-group">
				<label for="editSoftware_Hosts">Hosts</label>
				<input type="text" class="form-control" id="editSoftware_Hosts" placeholder="Hostnames">
			</div>
			<input type="hidden" id="editSoftware_Id" value=''>
			
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
				<button type="button" class="btn btn-primary" id="assets_edit_software_submit" data-dismiss="modal" >Update Software</button>
			</div>
		</div>
	</div>
</div>

<script>
	csts.onLoad(function(){
		csts.setHeader("Package Manager - <span id='package'>{{package}}</span> - Software");
	});
	
	client.software = {
		edit : function( softwareId ){
			jQuery('#editSoftware_Id').val( softwareId );
			jQuery('#editSoftware_Name').val( ((jQuery('#software_' + softwareId).parent().siblings()[0]).innerText) );
			jQuery('#editSoftware_Version').val( ((jQuery('#software_' + softwareId).parent().siblings()[1]).innerText) );
			jQuery('#editSoftware_Vendor').val( ((jQuery('#software_' + softwareId).parent().siblings()[2]).innerText) );
			jQuery('#editSoftware_Hosts').val( ((jQuery('#software_' + softwareId).parent().siblings()[3]).innerText) );
			jQuery('#myEditModal').modal();
		}
	}
</script>	