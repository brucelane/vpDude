package com.hillelcoren.assets.skins
{
	import flash.display.Graphics;
	
	import mx.skins.ProgrammaticSkin;

	public class MacMailSkin extends ProgrammaticSkin 
	{
		private static const RADIUS:int = 20;
		
		override protected function updateDisplayList( w:Number, h:Number ):void 
		{	
			var color:uint;
			
			switch (name) 
			{
				case "upSkin":
					color = 0xEFF2F7;
					break;
				case "overSkin":
					color = 0xe9e9e9;
					break;
				case "downSkin":
				case "selectedUpSkin":
				case "selectedOverSkin":
				case "selectedDownSkin":
					color = 0xa6a6a6;
			}
			
			var g:Graphics = graphics;
			g.clear();
			g.beginFill( color );
			g.lineStyle( 1, 0xe3e3e3 );
			g.drawRoundRect( 0, 1, w, h-2, RADIUS );
			g.endFill();
		}
	}
}