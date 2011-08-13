import com.hillelcoren.components.AutoComplete;

import flash.events.TimerEvent;
import flash.utils.Timer;

import mx.collections.ArrayCollection;
import mx.collections.XMLListCollection;
import mx.core.FlexGlobals;
import mx.events.FlexEvent;
import mx.messaging.management.Attribute;

import videopong.Clips;
import videopong.Tags;

[Bindable]
private var tags:Tags = Tags.getInstance();
[Bindable]
private var clips:Clips;

private var _data:XML;
private var ac:ArrayCollection;
private var tagArray:Array = [];
private var timer:Timer;

public function set data( value:XML ) : void 
{
	_data = value;
	//tagsXMLList = new XMLListCollection( _data..tags.tag.@name );
	tagAutoComplete.dataProvider = tags.tagsXMLList;
	_data..tags.tag.
	(
		tagArray.push( attribute("name") )
	);
	ac = new ArrayCollection( tagArray );
	tagAutoComplete.selectedItems = ac;
	//clipName.text = _data.clip.@name;	
	
}

private function handleTagButtonClick():void
{
	
	//TODO tagAutoComplete.dataProvider = tags.tagsXMLList;
	if (tagAutoComplete.isDropDownVisible())
	{
		tagAutoComplete.hideDropDown();
	}
	else
	{
		tagAutoComplete.search();
		tagAutoComplete.showDropDown();
	}
}
private function handleTagAutoCompleteChange():void
{
	trace("change");
}
protected function tagedit_creationCompleteHandler(event:FlexEvent):void
{
	tagAutoComplete.setStyle( "selectedItemStyleName", AutoComplete.STYLE_FACEBOOK );
	timer = new Timer(120000,1);
	timer.addEventListener(TimerEvent.TIMER, removeTagInput);
	timer.start();
}

protected function applyBtn_clickHandler(event:MouseEvent):void
{
	// write tags to clip and tags XML
	trace(tagAutoComplete.selectedItems);
	clips = Clips.getInstance();
	//remove existing tags
	clips.removeTags( _data.@id );
	//loop in tags and add them to XML db
	for each ( var oneTag:String in tagAutoComplete.selectedItems )
	{
		tags = Tags.getInstance();
		// if tag not already in global tags, add it
		tags.addTagIfNew( oneTag.toLowerCase() );
		
		//test if tag is not already in clip
		clips.addTagIfNew( oneTag.toLowerCase(), _data.@id  );
	}
	//remove textInput
	deleteTagTextInput();
}	
protected function cancelBtn_clickHandler(event:MouseEvent):void
{
	//remove textInput
	deleteTagTextInput();
}
private function removeTagInput(event:Event): void 
{
	//remove textInput
	deleteTagTextInput();
}
private function deleteTagTextInput( event:FocusEvent=null ):void 
{
	if ( timer )
	{
		timer.stop();
		timer = null;	
	}
	if ( FlexGlobals.topLevelApplication.tabNav.selectedChild is components.Search )
	{
		FlexGlobals.topLevelApplication.tabNav.selectedChild.tagHGroup.removeElement( this );
	}
}