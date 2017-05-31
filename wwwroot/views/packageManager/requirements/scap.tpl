<div class="tab-pane fade" role="tabpanel" id="req-scap" aria-labelledby="req-scap-tab"> 
	<p>
		<div class="panel panel-primary">
			<div class="panel-heading">
				<div class="row">
					<div class="col-md-6">
						<h3 class="panel-title">SCAP Requirements</h3>
					</div>
					<div class="col-md-6">
						
					</div>
				</div>
			</div>
			<div class="panel-body">
				<table class="table table-striped sortable" id="reqScapTab">
					<thead>
						<tr>
							<th class="col-md-2">Hostname</th>
							<th class="col-md-1">IP</th>
							<th class="col-md-4">Available Benchmarks</th>
							<th class="col-md-1"></th>
							<th class="col-md-4">Selected Benchmarks</th>
						</tr>
					</thead>
					<tbody>
						{{reqScapTab}}
					</tbody>
				</table>
			</div>
		</div>
	</p> 
</div>

<script>
	csts.onLoad(function(){ 
		jQuery('[data-toggle="tooltip"]').tooltip(); 
		jQuery('select.selScap').each(function(){
			client.requirements.scap.sort(this.id);
		})
	});
	
	client.requirements = client.requirements || {};
	client.requirements.scap = {
		sort : function(dest){
			var a = new Array();
			jQuery( '#' + dest ).children("option").each(function(x){
				test = false;
				b = a[x] = jQuery(this).text();
				for (i=0;i<a.length-1;i++){
					if (b == a[i]) test = true;
				}
				if (test) jQuery(this).remove();
			});
				
			var my_options = jQuery( '#' + dest ).children("option");
			my_options.sort(function(a,b) {
				if (a.text.toLowerCase() > b.text.toLowerCase()) return 1;
				if (a.text.toLowerCase() < b.text.toLowerCase()) return -1;
				return 0;
			});
			jQuery('#' + dest).empty().append( my_options );
			
		},
		add : function(src, dest){
			jQuery('#' + src + ' option:selected').clone().appendTo( '#' + dest );
			client.requirements.scap.sort(dest);
		},
		remove : function(src){
			jQuery('#' + src + ' option:selected').remove();
		},
		removeAll : function(src){
			jQuery('#' + src + ' option:selected').each(function(){
				value = this.text
				jQuery("select.selScap option").each(function(){
					if(this.text == value){
						jQuery(this).remove();
					}
				});
			});
		},
		addAll : function(src){
			jQuery('select.selScap').each(function(){
				client.requirements.scap.add(src, this.id)
			});
		}
	};
	
</script>	