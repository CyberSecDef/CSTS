<h1 class="page-header">Hosts</h1>
<div class="col-sm-12 col-md-12 main">
	<div class="table-responsive">
		<button class="btn btn-info" id="assets_ad_import_hosts_button" data-toggle="modal" data-target="#myADModal" >Import from Active Directory</button>
		<button class="btn btn-primary" data-toggle="modal" data-target="#myModal">Add Hosts</button>
		<button class="btn btn-danger" id="assets_remove_hosts_button">Remove Hosts</button>
		<button class="btn btn-success" id="assets_reload_hosts_button">Reload Host Data</button>
		<button class="btn btn-info" id="asset_reload_host_software_submit" >Reload Host Software</button>
		
		<br /><br />
		<table class="table table-striped table-hover table-condensed sortable exportable" id="hosts">
			<thead>
			<tr>
				<th><input type="checkbox" onclick="jQuery('table#hosts tr td input').trigger('click')" ></th>
				<th>Hostname</th>
				<th>IP</th>
				<th>Device Type</th>
				<th>Operating System</th>
				<th>Manufacturer</th>
				<th>Model</th>
				<th>Firmware</th>
				<th>Location</th>
				<th>Description</th>
			</tr>
			</thead>
			<tbody>
				{{assetList}}
			</tbody>
		</table>
		<hr>
		<caption>
			There are <strong>{{assetCount}}</strong> hosts in the Official <strong><u>{{Package}}</u></strong> package.
		</caption>
	</div>
</div>

<!-- Modal -->
<div class="modal fade" id="myModal" tabindex="-1" role="dialog" aria-labelledby="myModalLabel">
	<div class="modal-dialog" role="document">
		<div class="modal-content">
			<div class="modal-header">
				<button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
				<h4 class="modal-title" id="myModalLabel">Enter Hosts Seperated by Commas</h4>
			</div>
			<div class="modal-body">
				<textarea class="form-control" rows="3" id="txtNewHosts" name="txtNewHosts"></textarea>
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
				<button type="button" class="btn btn-primary" id="assets_add_hosts_submit" data-dismiss="modal" >Add Hosts</button>
			</div>
		</div>
	</div>
</div>

<div class="modal fade" id="myEditModal" tabindex="-1" role="dialog" aria-labelledby="myModalLabel">
	<div class="modal-dialog" role="document">
		<div class="modal-content">
			<div class="modal-header">
				<button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
				<h4 class="modal-title" id="myModalLabel">Edit Host</h4>
			</div>
			<div class="modal-body">
				
			<div class="form-group">
				<label for="editHost_HostName">Hostname</label>
				<input type="text" class="form-control" id="editHost_HostName" placeholder="Hostname">
			</div>
			<div class="form-group">
				<label for="editHost_IP">IP</label>
				<input type="text" class="form-control" id="editHost_IP" placeholder="IP">
			</div>
			
			<div class="form-group">
				<label for="editHost_OS">Operating System</label>
				<input type="text" class="form-control" id="editHost_OS" placeholder="OS">
			</div>
			<div class="form-group">
				<label for="editHost_OSProdKey">Operating System Product Key</label>
				<input type="text" class="form-control" id="editHost_OSProdKey" placeholder="OSProdKey">
			</div>
			<div class="form-group">
				<label for="editHost_deviceType">Device Type</label>
				<select class="form-control" id="editHost_deviceType">
					<option>Workstation</option>
					<option>Server</option>
					<option>Printer</option>
					<option>Other</option>
				</select>
			</div>
			
			<div class="form-group">
				<label for="editHost_Manufacturer">Manufacturer</label>
				<input type="text" class="form-control" id="editHost_Manufacturer" placeholder="Manufacturer">
			</div>
			<div class="form-group">
				<label for="editHost_Model">Model</label>
				<input type="text" class="form-control" id="editHost_Model" placeholder="Model">
			</div>
			<div class="form-group">
				<label for="editHost_Firmware">Firmware</label>
				<input type="text" class="form-control" id="editHost_Firmware" placeholder="Firmware">
			</div>
			
			<div class="form-group">
				<label for="editHost_Location">Location</label>
				<input type="text" class="form-control" id="editHost_Location" placeholder="Location">
			</div>
			
			<div class="form-group">
				<label for="editHost_Description">Description</label>
				<input type="text" class="form-control" id="editHost_Description" placeholder="Description">
			</div>
			
			<input type="hidden" id="editHost_Id" value=''>
			
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
				<button type="button" class="btn btn-primary" id="assets_edit_hosts_submit" data-dismiss="modal" >Update Host</button>
			</div>
		</div>
	</div>
</div>


<div class="modal fade" id="myADModal" tabindex="-1" role="dialog" aria-labelledby="myModalLabel">
	<div class="modal-dialog" role="document">
		<div class="modal-content">
			<div class="modal-header">
				<button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
				<h4 class="modal-title" id="myModalLabel">Import Hosts from Active Directory</h4>
			</div>
			<div class="modal-body" style="height:500px; overflow:scroll;">
				<div id="tree" class="col-md-12" ></div>
				<input type="textbox" name="importOU" id="importOU" value="" />
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
				<button type="button" class="btn btn-primary" id="assets_import_hosts_button"  >Import Hosts</button>
			</div>
		</div>
	</div>
</div>


<script>
	csts.onLoad(
		function(){
			csts.setHeader("Package Manager - <span id='package'>{{package}}</span> - Assets");
			jQuery('#tree').treeview( {data: client.assets.ad.getTree()});
			jQuery('#tree').on( 'nodeSelected', function(event, data){ 
				client.assets.ad.getPath(data.nodeId);
				jQuery('#importOU').val( client.assets.ad.ous.join('\\') );
			});
		}
	);
	
	client.assets = {
		ad : {
			ous : [],
			getPath : function(nodeId){
				node = jQuery('#tree').treeview('getNode', nodeId);
				this.ous.push(node.text);
				if( ( (node.parentId) && (typeof node.parentId ) != undefined ) && (node.parentId !== null) ){
					this.getPath(node.parentId);
				}
			},
			getTree : function(){
				var tree = [{{adTree}}];
				return tree;
			}
		},
		hosts : {
			edit : function(hostId){
				jQuery('#editHost_Id').val( hostId );
				jQuery('#editHost_HostName').val( ((jQuery('#host_' + hostId).parent().siblings()[0]).innerText) );
				jQuery('#editHost_IP').val( ((jQuery('#host_' + hostId).parent().siblings()[1]).innerText) );
				jQuery('#editHost_deviceType').val( ((jQuery('#host_' + hostId).parent().siblings()[2]).innerText) );
				jQuery('#editHost_OS').val( ((jQuery('#host_' + hostId).parent().siblings()[3]).innerText) );
				
				jQuery('#editHost_OSProdKey').val( jQuery( jQuery('#host_' + hostId).parent().siblings()[0] ).find('a').attr('title') );
				
				jQuery('#editHost_Manufacturer').val( ((jQuery('#host_' + hostId).parent().siblings()[4]).innerText) );
				jQuery('#editHost_Model').val( ((jQuery('#host_' + hostId).parent().siblings()[5]).innerText) );
				jQuery('#editHost_Firmware').val( ((jQuery('#host_' + hostId).parent().siblings()[6]).innerText) );
				jQuery('#editHost_Location').val( ((jQuery('#host_' + hostId).parent().siblings()[7]).innerText) );
				jQuery('#editHost_Description').val( ((jQuery('#host_' + hostId).parent().siblings()[8]).innerText) );
				jQuery('#myEditModal').modal();
			}
		}
	};
</script>	