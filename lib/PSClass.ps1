# #########################################################################
# Class: psClass
# 	creates a pseudo-object oriented architecture within powershell
# #########################################################################
function New-PSClass( 
	[string] $ClassName = { Throw "ClassName required for New-PSClass"}, 
	[scriptblock] $definition = { Throw "Definition required for New-PSClass"}, 
	$Inherit
){
  
	# #########################################################################
	# Method: Constructor
	# 	Assigns Constructor script to Class
	#
	# Parameters:
	#	[scriptblock] $script - The scriptBlock used to construct the object
	#
	# Returns:
	# 	New <psClass> Object
	#
	# See Also:
	# 	
	# #########################################################################
	function constructor( 
		[scriptblock] $script=$(Throw "Script is required for 'constructor' in $ClassName")
	){
		if ($class.ConstructorScript){
			Throw "Only one Constructor is allowed"
		}
		$class.ConstructorScript = $script
	}
  
	# #########################################################################
	# Method: note
	#   Adds Notes record to class if non-static
	#
	# Returns:
	# 	N/A
	# #########################################################################
	function note{
		param ( 
			[string]$name={Throw "Note Name is Required"}, 
			$value="", 
			[switch] $private, 
			[switch] $static
		)
    
		if ($static){
			if ($private){
				Throw "Private Static Notes are not supported"
			}
			Attach-PSNote $class $name $value
		}else{
			$class.Notes += @{Name=$name;DefaultValue=$value;Private=$private}
		}
	}

	# #########################################################################
	# Method: method
	#   Add a method script to Class definition or 
	#   attaches it to the Class if it is static
	#
	# Returns:
	# 	N/A
	# #########################################################################  
	function method( 
		[string]$name=$(Throw "Name is required for 'method'"),
		[scriptblock] $script=$(Throw "Script is required for 'method' $name in Class $ClassName"),
		[switch] $static,
		[switch]$private,
		[switch]$override
	){
		if ($static){
			if ($private){
				Throw "Private Static Methods not supported"
			}
			Attach-PSScriptMethod $class $name $script
		}else{
			$class.Methods[$name] = @{Name=$name;Script=$script;Private=$private;Override=$override}
		}
	}
  
	# #########################################################################
	# Method: property
	#   Add a property to Class definition or 
	#   attaches it to the Class if it is static
	#
	# Returns:
	# 	N/A
	# #########################################################################  
	function property(
		[string]$name, 
		[scriptblock] $get, 
		[scriptblock] $set, 
		[switch]$private, 
		[switch]$override, 
		[switch] $static 
	){
		if ($static){
			if ($private){
				Throw "Private Static Properties not supported"
			}
			Attach-PSProperty $class $name $get $set 
		}else{
			$class.Properties[$name] = @{Name=$name;GetScript=$get;SetScript=$set;Private=$private;Override=$override}
		}
	}

	
	$class = new-object Management.Automation.PSObject

	Attach-PSNote $class ClassName $ClassName
	Attach-PSNote $class Notes @()
	Attach-PSNote $class Methods @{}
	Attach-PSNote $class Properties @{}
	Attach-PSNote $class BaseClass $Inherit
	Attach-PSNote $class ConstructorScript
	Attach-PSNote $class PrivateName "__$($ClassName)_Private"

	Attach-PSScriptMethod $class AttachTo {
		function AttachAndInit($instance, [array]$parms){
			$instance = __PSClass-AttachObject $this $instance
			__PSClass-Initialize $this $instance $parms
			$instance
		}
		$type = $Args[0].GetType()
		[array]$parms = $Args[1]
		if (($Args[0] -is [array]) -or ($Args[0] -is [System.Collections.ArrayList])){
			# This handles the attachment of an array of objects
			$objects = $Args[0]
			foreach($object in $objects){
				$(AttachAndInit $object $parms) > $null
			}
		}else{
			AttachAndInit $Args[0] $parms
		}
	}
	
	Attach-PSScriptMethod $class New {
		$instance = new-object Management.Automation.PSObject
		$this.AttachTo( $instance, $Args )  
	}

	Attach-PSScriptMethod $class __LookupClassObject {
		__PSClass-LookupClassObject $this $Args[0] $Args[1]
	}

	Attach-PSScriptMethod $class InvokeMethod {
		__PSClass-InvokeMethod $this $Args[0] $Args[1] $Args[2]
	}

	Attach-PSScriptMethod $class InvokeProperty {
		__PSClass-InvokePropertyMethod $this $Args[0] $Args[1] $Args[2] $Args[3]
	}

	$output = &$definition
	if ($output -ne $null){
		Throw "PSClass Definition has invalid output objects $output"
	}

	# return constructed class
	$class
}


# #########################################################################  
# Section: Private Helper Cmdlets
#
# These helper Cmdlets should only be called by New-PSClass.  They exist to 
# reduce the amount of code attached to each PSClass object.  They rely on 
# context variables not passed as parameters.
# #########################################################################  

# #########################################################################
# Method: __PSClass-Initialize
#    Invokes Constructor Script and provides helper Base function to facilitate
#    Inherited Constructors
#
# Returns:
# 	N/A
# #########################################################################  
function __PSClass-Initialize (
	$class, 
	$instance, 
	$params
){
	function Base{
		if ($this.Class.BaseClass -eq $null){
			Throw "No BaseClass implemented for $($this.Class.ClassName)"
		}
		__PSClass-Initialize $this.Class.BaseClass $this $Args
	}
  
	trap{
		if ( $_.Exception.Message -match "Error Position:" ){
			$errorMsg = $_.Exception.Message 
		}else{
			$errorMsg = $_.Exception.Message + @"

Error Position: 
"@ + $_.Exception.ErrorRecord.InvocationInfo.PositionMessage
		}
    
		$errorMsg = ($errorMsg -replace '(Exception calling ".*" with ".*" argument\(s\)\: ")(.*)','' )
		Throw $errorMsg
	}
  
	if ($class.ConstructorScript){
		$constructor = $class.ConstructorScript
		
		$private = $Instance.($class.privateName)
		$this = $instance
		$self = $this 
	
		$constructor.InvokeReturnAsIs( $params )
	}
}

# #########################################################################
# Method: __PSClass-AttachObject
#    Attaches Notes, Methods, and Properties to Instance Object
#
# Returns:
# 	N/A
# #########################################################################  
function __PSClass-AttachObject (
	$Class, 
	[PSObject] $instance
){
	function AssurePrivate{
		if ($instance.($Class.privateName) -eq $null){
			Attach-PSNote $instance ($class.privateName) (new-object Management.Automation.PSObject)
			Attach-PSNote $instance.($class.privateName) __Parent
		}
		$instance.($class.privateName).__Parent = $instance
	}

	# - - - - - - - - - - - - - - - - - - - - - - - -
	#  Attach BaseClass
	# - - - - - - - - - - - - - - - - - - - - - - - -
	if ($Class.BaseClass -ne $null){
		$instance = __PSClass-AttachObject $Class.BaseClass $instance
	}

	Attach-PSNote $instance Class $Class

	# - - - - - - - - - - - - - - - - - - - - - - - -
	#  Attach Notes
	# - - - - - - - - - - - - - - - - - - - - - - - -
	foreach ($note in $Class.Notes){
		if ($note.private){
			AssurePrivate
			Attach-PSNote $instance.($Class.privateName) $note.Name $note.DefaultValue
		}else{
			Attach-PSNote $instance $note.Name $note.DefaultValue
		}
	}

	# - - - - - - - - - - - - - - - - - - - - - - - -
	#  Attach Methods
	# - - - - - - - - - - - - - - - - - - - - - - - -
	foreach ($key in $Class.Methods.keys){
		$method = $Class.Methods[$key]
		$targetObject = $instance
  
		# Private Methods are attached to the Private Object.
		# However, when the script gets invoked, $this needs to be
		# pointing to the instance object. $ObjectString resolves
		# this for InvokeMethod
		if ($method.private){
			AssurePrivate
			$targetObject = $instance.($Class.privateName)
			$ObjectString = '$this.__Parent'
		}else{
			$targetObject = $instance
			$ObjectString = '$this'
		}
  
		# The actual script is not attached to the object.  The Script attached to Object calls 
		# InvokeMethod on the Class.  It looks up the script and executes it
		$instanceScriptText = $ObjectString + '.Class.InvokeMethod( "' + $method.name + '", ' + $ObjectString + ', $Args )'
		$instanceScript = $ExecutionContext.InvokeCommand.NewScriptBlock( $instanceScriptText )

		Attach-PSScriptMethod $targetObject $method.Name $instanceScript  -override:$method.override
	}

	# - - - - - - - - - - - - - - - - - - - - - - - -
	#  Attach Properties
	# - - - - - - - - - - - - - - - - - - - - - - - -
	foreach ($key in $Class.Properties.keys){
		$Property = $Class.Properties[$key]
		$targetObject = $instance

		# Private Properties are attached to the Private Object.
		# However, when the script gets invoked, $this needs to be
		# pointing to the instance object. $ObjectString resolves
		# this for InvokeMethod
		if ($Property.private){
			AssurePrivate
			$targetObject = $instance.($Class.privateName)
			$ObjectString = '$this.__Parent'
		}else{
			$targetObject = $instance
			$ObjectString = '$this'
		}

		# The actual script is not attached to the object.  The Script attached to Object calls 
		# InvokeMethod on the Class.  It looks up the script and executes it
		$instanceScriptText = $ObjectString + '.Class.InvokeProperty( "GET", "' + $Property.name + '", ' + $ObjectString + ', $Args )'
		$getScript = $ExecutionContext.InvokeCommand.NewScriptBlock( $instanceScriptText )
  
		if ($Property.SetScript -ne $null){
			$instanceScriptText = $ObjectString + '.Class.InvokeProperty( "SET", "' + $Property.name + '", ' + $ObjectString + ', $Args )'
			$setScript = $ExecutionContext.InvokeCommand.NewScriptBlock( $instanceScriptText )
		}else{
			$setScript = $null
		}
  
		Attach-PSProperty $targetObject $Property.Name $getScript $setScript -override:$Property.override
	}
	$instance
}

# #########################################################################
# Method: __PSClass-LookupClassObject
#   intended to look up methods and property objects on the Class.  However, 
#   it can be used to look up any Hash Table entry on the class.
#
#   if the object is not found on the instance class, it searches all Base Classes
#   
#   $ObjectType is the HashTable Member
#   $ObjectName is the HashTable Key
#
# Returns:
# 	the Class and Hashtable entry it was found in
# #########################################################################  
function __PSClass-LookupClassObject (
	$Class, 
	$ObjectType, 
	$ObjectName
){
	$object = $Class.$ObjectType[$ObjectName]
	if ($object -ne $null){
		$Class
		$object
	}else{
		if ($Class.BaseClass -ne $null){
			$Class.BaseClass.__LookupClassObject($ObjectType, $ObjectName)
		}
	}
}

# #########################################################################
# Method: __PSClass-InvokeScript
#   Used to invoke Method and Property scripts
#     It adds an error handler so Script Info can be seen in the error
#     It marshals $this and $private variables for the context of the script
#     It provides a helper Invoke-BaseClassMethod for invoking base class methods
#
# Returns:
# 	N/A
# #########################################################################  
function __PSClass-InvokeScript(
	$class, 
	$script, 
	$object, 
	[array]$parms,
	$methodName
){
	
	function Invoke-BaseClassMethod (
		$methodName, 
		[array]$parms
	){
 		if ($this.Class.BaseClass -eq $null){
			Throw "$($this.Class.ClassName) does not have a BaseClass"
		}
		$class,$method = $this.Class.BaseClass.__LookupClassObject('Methods', $MethodName)
    
		if ($method -eq $null){
			Throw "Method $MethodName not defined for $className"
		}
		
		__PSClass-InvokeScript $class $method.Script $this $parms
	}
  
	trap {
		if ( $_.Exception.Message -match "Error Position:" ){
			$errorMsg = $_.Exception.Message 
		}else{
			$errorMsg = $_.Exception.Message + @"

Error Position: 
"@ + $_.Exception.ErrorRecord.InvocationInfo.PositionMessage
		}
    
		$errorMsg = ($errorMsg -replace '(Exception calling ".*" with ".*" argument\(s\)\: ")(.*)','' )
		Throw $errorMsg
	}
	
	
	$this = $object
	$private = $this.($Class.privateName)

	
	$script.InvokeReturnAsIs( $parms )
	
}

# #########################################################################
# Method: __PSClass-InvokeMethod
#   Script called by methods attached to instances.  Looks up Method Script
#   in instance class or in inherited class
#
# Returns:
# 	N/A
# #########################################################################  
function __PSClass-InvokeMethod(
	$Class, 
	$MethodName, 
	$instance, 
	[array]$parms
){
	$FoundClass,$method = $Class.__LookupClassObject('Methods', $MethodName)
  
	if ($method -eq $null){
		 Throw "Method $MethodName not defined for $($Class.ClassName)"
	}
		
	__PSClass-InvokeScript $FoundClass $method.Script $instance $parms $methodName
	
}

# #########################################################################
# Method: __PSClass-InvokePropertyMethod
#   Script called by property scripts attached to instances.  Looks up property Script
#   in instance class or in inherited class
#
# Returns:
# 	N/A
# #########################################################################  
function __PSClass-InvokePropertyMethod(
	$Class, 
	$PropertyType, 
	$PropertyName, 
	$instance, 
	[array]$parms
){
	$FoundClass,$property = $Class.__LookupClassObject('Properties', $PropertyName)
  
	if ($property -eq $null){
		Throw "Property $PropertyName not defined for $($Class.ClassName)"
	}

	if ($PropertyType -eq "GET"){
		__PSClass-InvokeScript $FoundClass $property.GetScript $instance $parms
	}else{
		__PSClass-InvokeScript $FoundClass $property.SetScript $instance $parms
	}
}


# #########################################################################  
# Section: Public Helper Cmdlets
#
# These helper Cmdlets should only be called by New-PSClass.  They exist to 
# reduce the amount of code attached to each PSClass object.  They rely on 
# context variables not passed as parameters.
# #########################################################################  

# #########################################################################
# Method: Attach-PSNote 
#	Attaches a PowerShell Note to the PSClass instance
#
# Returns:
# 	N/A
# #########################################################################  
function Attach-PSNote{
	param( 
		[PSObject]$object=$(Throw "Object is required"),
		[string]$name=$(Throw "Note Name is Required"),
		$value
	)
  
	if (! $object.psobject.members[$name]){
		$member = new-object management.automation.PSNoteProperty $name,$value
        $object.psobject.members.Add($member)
	}
	
	if($value){
		$object.$name = $value
	}
}

# #########################################################################
# Method: Attach-PSScriptMethod
#	Attaches a PowerShell Method to the PSClass instance
#
# Returns:
# 	N/A
# #########################################################################  
function Attach-PSScriptMethod{
	param ( 
		[PSObject]$object=$(Throw "Object is required"),
		[string]$name=$(Throw "Method Name is Required"),
		[scriptblock] $script,
		[switch] $override
	)
  
	$member = new-object management.automation.PSScriptMethod $name,$script
  
	if ($object.psobject.members[$name] -ne $null){
		if ($override){
			$object.psobject.members.Remove($name)
		}else{
			Throw "Method '$name' already exists with out 'override'"
		}
	}
  
	$object.psobject.members.Add($member)
}

# #########################################################################
# Method: Attach-PSProperty
#	Attaches a PowerShell Property to the PSClass instance
#
# Returns:
# 	N/A
# #########################################################################  
function Attach-PSProperty{
	param ( 
		[PSObject]$object=$(Throw "Object is required"),
		[string]$name=$(Throw "Method Name is Required"),
		[scriptblock] $get=$(Throw "get script is required on property $name in Class $ClassName"),
		[scriptblock] $set,
		[switch] $override         
	)
  
	if($set){
		$scriptProperty = new-object management.automation.PsScriptProperty `
		$name,$get,$set
	}else{
		$scriptProperty = new-object management.automation.PsScriptProperty `
		$name,$get
	}    
  
	if ( $object.psobject.properties[$name] -and $override){
		$object.psobject.properties.Remove($name)
	}
  
	$object.psobject.properties.add($scriptProperty)
}