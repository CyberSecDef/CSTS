var csts = {
	onLoad : function(func){
		document.addEventListener(
			'DOMContentLoaded', func , 
			false
		);
	},
	setHeader : function(msg){
		jQuery('div.navbar-header a.navbar-brand').html(msg);
		
	}
	
	
}