<div class="tab-pane fade" role="tabpanel" id="req-ckl" aria-labelledby="req-ckl-tab"> 
	<p>
		<div class="panel panel-primary">
			<div class="panel-heading">
				<div class="row">
					<div class="col-md-6">
						<h3 class="panel-title">CKL Requirements</h3>
					</div>
					<div class="col-md-6">
						
					</div>
				</div>
			</div>
			<div class="panel-body">
				<div class="row">
					<div class="col-md-6">
						<select multiple="multiple" class="form-control input-sm" size="20" id="avail-stig">
						  {{availCkl}}
						</select>
					</div>
					<div class="col-md-1" style="padding-top:100px;">
						<button class="btn btn-default" onclick="client.requirements.ckl.add();"> --&gt; </button>
						<br /><br />
						<button class="btn btn-default" onclick="client.requirements.ckl.remove();"> &lt;-- </button>
					</div>
					<div class="col-md-5">
						<select multiple='multiple' class="form-control input-sm" size="20" id="sel-stig">
							{{selCkl}}
						</select>
					</div>
				</div>
			</div>
		</div>
	</p> 
</div>

<script>
	client.requirements = client.requirements || {};
	client.requirements.ckl = {
		add : function(){
			jQuery('select#avail-stig :selected').clone().appendTo('select#sel-stig');
			
			var a = new Array();
			jQuery('select#sel-stig ').children("option").each(function(x){
				test = false;
				b = a[x] = jQuery(this).text();
				for (i=0;i<a.length-1;i++){
					if (b == a[i]) test =true;
				}
				if (test) jQuery(this).remove();
			});
			
			var my_options = jQuery( 'select#sel-stig' ).children("option");
			my_options.sort(function(a,b) {
				if (a.text.toLowerCase() > b.text.toLowerCase()) return 1;
				if (a.text.toLowerCase() < b.text.toLowerCase()) return -1;
				return 0;
			});
			jQuery('select#sel-stig').empty().append( my_options );
			
		},
		remove : function(){
			jQuery('select#sel-stig :selected').each(function(){
				jQuery(this).remove();
			})
		}
	}
</script>	