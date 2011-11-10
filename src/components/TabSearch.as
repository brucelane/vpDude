import com.hillelcoren.components.AutoComplete;

import fr.batchass.*;

import mx.collections.ArrayCollection;
import mx.collections.XMLListCollection;
import mx.events.FlexEvent;

import spark.events.TextOperationEvent;

import videopong.*;

private var isConfigured:Boolean = false;
[Bindable]
private	var clips:Clips = Clips.getInstance();
[Bindable]
private var tags:Tags = Tags.getInstance();

private var timer:Timer;

private function timerFct(event:Event):void
{
	applyLabel.text = "";
	timer.stop();

}
private function handleButtonClick():void
{
	
	autoComplete.dataProvider = tags.tagsXMLList;
    if (autoComplete.isDropDownVisible())
    {
        autoComplete.hideDropDown();
    }
    else
    {
        autoComplete.search();
        autoComplete.showDropDown();
    }
}
private function handleAutoCompleteChange():void
{
	clips.filterTags( autoComplete.selectedItems );		
}
protected function search_creationCompleteHandler(event:FlexEvent):void
{
	autoComplete.setStyle( "selectedItemStyleName", AutoComplete.STYLE_FACEBOOK );
	autoComplete.dataProvider = tags.tagsXMLList;
	tagAutoComplete.setStyle( "selectedItemStyleName", AutoComplete.STYLE_FACEBOOK );
	tagAutoComplete.dataProvider = tags.tagsXMLList;
	
	clipList.labelField = "@name";
	timer = new Timer(2500);
	timer.addEventListener(TimerEvent.TIMER, timerFct);

}
private function handleTagButtonClick():void
{	
	//TODO tagAutoComplete.dataProvider = tags.tagsXMLList;
	if ( tagAutoComplete.isDropDownVisible() )
	{
		tagAutoComplete.hideDropDown();
	}
	else
	{
		tagAutoComplete.search();
		tagAutoComplete.showDropDown();
	}
	
}
protected function tabSearchApplyBtn_clickHandler(event:MouseEvent):void
{
	if ( tagAutoComplete.data )
	{
		applyLabel.text = "Tags updated...";
		// write tags to clip and tags XML
		clips = Clips.getInstance();
		//remove existing tags
		clips.removeTags( tagAutoComplete.data.@id );//resets search view!!!
		//loop in tags and add them to XML db
		for each ( var oneTag:String in tagAutoComplete.selectedItems )
		{
			tags = Tags.getInstance();
			// if tag not already in global tags, add it
			tags.addTagIfNew( oneTag.toLowerCase() );//no reset:ok
			
			//test if tag is not already in clip
			clips.addTagIfNew( oneTag.toLowerCase(), tagAutoComplete.data.@id, false );//resets search view!!!
		}
		timer.start();
	}
}	
