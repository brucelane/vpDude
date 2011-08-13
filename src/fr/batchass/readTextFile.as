package fr.batchass
{
	import flash.filesystem.*;
	
	/**
	 * 	Simple utility to read a text file synchronously
	 */
	public function readTextFile( file:File ):String 
	{
		
		// create connection
		const stream:FileStream = new FileStream();
		stream.open( file, FileMode.READ );
		
		const value:String = stream.readUTFBytes( stream.bytesAvailable );
		
		// close the file
		stream.close();
		
		// return		
		return value;
	}
	
}