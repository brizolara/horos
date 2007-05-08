/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - GPL
  
  See http://homepage.mac.com/rossetantoine/osirix/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

#include "FVTiff.h"

#import "XMLController.h"
#import "XMLControllerDCMTKCategory.h"
#import "WaitRendering.h"
#import "dicomFile.h"
#import "BrowserController.h"
#import <OsiriX/DCMObject.h>

static NSString* 	XMLToolbarIdentifier					= @"XML Toolbar Identifier";
static NSString*	ExportToolbarItemIdentifier				= @"Export.icns";
static NSString*	ExportTextToolbarItemIdentifier			= @"ExportText";
static NSString*	ExpandAllItemsToolbarItemIdentifier		= @"add-large";
static NSString*	CollapseAllItemsToolbarItemIdentifier	= @"minus-large";
static NSString*	SearchToolbarItemIdentifier				= @"Search";

@implementation XMLController

- (NSString*) getPath:(NSXMLElement*) node
{
	NSMutableString	*result = [NSMutableString string];
	
	id parent = node;
	id child = 0L;
	BOOL first = TRUE;
	
	do
	{
		if( [[[parent parent] className] isEqualToString:@"NSXMLElement"])
		{
			if( [[parent attributeForName:@"group"] stringValue] && [[parent attributeForName:@"element"] stringValue])
			{
				NSString *subString = [NSString stringWithFormat:@"(%@,%@)", [[parent attributeForName:@"group"] stringValue], [[parent attributeForName:@"element"] stringValue]];
				
				if( first == NO && [[child attributeForName:@"group"] stringValue] && [[child attributeForName:@"element"] stringValue])
					subString = [subString stringByAppendingString:@"."];
					
				[result insertString: subString atIndex: 0];
			}
			else
			{
				NSString *subString =  [NSString stringWithFormat:@"[%d]", [[[parent parent] children] indexOfObject: parent]];
				
				if( first == NO)
					subString = [subString stringByAppendingString:@"."];
				
				[result insertString: subString atIndex: 0];
			}
		}
		
		child = parent;
		first = NO;
	}
	while( parent = [parent parent]);
	
	NSLog( result);
	
	// Example (0008,1111)[0].(0010,0010)
	
	return result;
}

-(NSArray*) arrayOfFiles
{
	int i, result;
	
	[NSApp beginSheet: levelSelection
			modalForWindow:	[self window]
			modalDelegate: nil
			didEndSelector: nil
			contextInfo: nil];
	
	[NSApp runModalForWindow: levelSelection];

    [NSApp endSheet: levelSelection];
    [levelSelection orderOut: self];

	result = [levelMatrix selectedTag];
	
	switch ( result) 
	{
		case 0:
			NSLog( @"image level");
			return [NSArray arrayWithObject: srcFile];
		break;
		
		case 1:
			NSLog( @"series level");
			
			NSManagedObject	*series = [imObj valueForKey:@"series"];
			
			NSArray	*images = [[BrowserController currentBrowser] childrenArray: series];
			
			return [images valueForKey:@"completePath"];
		break;
		
		case 2:
			NSLog( @"study level");
			
			NSArray	*allSeries =  [[BrowserController currentBrowser] childrenArray: [imObj valueForKeyPath:@"series.study"]];
			NSMutableArray *result = [NSMutableArray array];
			
			for(i = 0 ; i < [allSeries count]; i++)
			{
				[result addObjectsFromArray: [[BrowserController currentBrowser] childrenArray: [allSeries objectAtIndex: i]]];
			}
			
			return [result valueForKey:@"completePath"];
		break;
	}
	
	return 0L;
}

-(void) reload:(id) sender
{
	[xmlDocument release];
	DCMObject *dcmObject = [DCMObject objectWithContentsOfFile:srcFile decodingPixelData:NO];
	xmlDocument = [[dcmObject xmlDocument] retain];
	
	int selectedRow = [table selectedRow];
	
	NSPoint origin = [[table superview] bounds].origin;
	
	[table reloadData];
	[table expandItem:[table itemAtRow:0] expandChildren:NO];
	
	[table selectRow: selectedRow byExtendingSelection: NO];
	[[tableScrollView contentView] scrollToPoint: origin];
	[tableScrollView reflectScrolledClipView: [tableScrollView contentView]];
	[table setNeedsDisplay];
}

-(void) exportXML:(id) sender
{
    NSSavePanel     *panel = [NSSavePanel savePanel];

    [panel setCanSelectHiddenExtension:NO];
    [panel setRequiredFileType:@"xml"];
    
    if( [panel runModalForDirectory:0L file:[[self window]title]] == NSFileHandlingPanelOKButton)
    {
		[[xmlDocument XMLString] writeToFile:[panel filename] atomically:NO];
    }
}

-(void) exportText:(id) sender
{
    NSSavePanel     *panel = [NSSavePanel savePanel];

    [panel setCanSelectHiddenExtension:NO];
    [panel setRequiredFileType:@"txt"];
    
    if( [panel runModalForDirectory:0L file:[[self window]title]] == NSFileHandlingPanelOKButton)
    {
		DCMObject *dcmObject = [DCMObject objectWithContentsOfFile:srcFile decodingPixelData:NO];
		[[dcmObject description] writeToFile: [panel filename] atomically:NO];
    }
}


- (void) windowDidLoad
{
    [self setupToolbar];
}

-(id) initWithImage:(NSManagedObject*) image windowName:(NSString*) name
{
	if (self = [super initWithWindowNibName:@"XMLViewer"]){
		[[self window] setTitle:name];
		[[self window] setFrameAutosaveName:@"XMLWindow"];
		[[self window] setDelegate:self];
		
		imObj = [image retain];
		srcFile = [[image valueForKey:@"completePath"] retain];
		
		if([DicomFile isDICOMFile:srcFile])
		{
			DCMObject *dcmObject = [DCMObject objectWithContentsOfFile:srcFile decodingPixelData:NO];
			xmlDocument = [[dcmObject xmlDocument] retain];
		}
		else if([DicomFile isFVTiffFile:srcFile])
		{
/*			NSXMLElement *rootElement = [[NSXMLElement alloc] initWithName:@"FVTiffFile"];
			xmlDocument = [[NSXMLDocument alloc] initWithRootElement:rootElement];
			[rootElement release];*/
			xmlDocument = XML_from_FVTiff(srcFile);
		}
		else
		{
			NSXMLElement *rootElement = [[NSXMLElement alloc] initWithName:@"Unsupported Meta-Data"];
			xmlDocument = [[NSXMLDocument alloc] initWithRootElement:rootElement];
			[rootElement release];
		}
		[table reloadData];
		[table expandItem:[table itemAtRow:0] expandChildren:NO];
		
		[search setRecentsAutosaveName:@"xml meta data search"];
	}
	return self;
}

- (void) dealloc
{
	[imObj release];
	[srcFile release];
	
    [xmlDcmData release];
    
    [xmlData release];
	
	[xmlDocument release];
    
	[toolbar setDelegate: 0L];
	[toolbar release];
	
    [super dealloc];
}

/*
- (void)finalize {
	//nothing to do does not need to be called
}
*/

- (void)windowWillClose:(NSNotification *)notification
{
	[self release];
}


- (IBAction) setSearchString:(id) sender
{
	
	[table reloadData];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    return YES;
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item 
{

        if( item == nil)
        {
            return [xmlDocument childCount];
        }
        else
        {
            return [item childCount];
        }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if( [[item valueForKey:@"name"] isEqualToString:@"value"])
		return NO;
	else
	{
		if([item childCount] == 1 && [[[[item children] objectAtIndex:0] valueForKey:@"name"] isEqualToString:@"value"])
			return NO;
		else if([item childCount] == 1 && [[[item children] objectAtIndex:0] kind] == NSXMLTextKind)
			return NO;
		else if([item childCount] == 0L)
			return NO;
		else
			return YES;
	}
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
        if( item == 0L)
        {
            return [xmlDocument childAtIndex:index];
        }
        else
        {
			return [item childAtIndex:index];
        }
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	BOOL found = NO;
	
	if( [[search stringValue] isEqualToString:@""] == NO)
	{
		NSRange range = [[item XMLString] rangeOfString: [search stringValue] options: NSCaseInsensitiveSearch];
		
		if( range.location != NSNotFound) found = YES;
		
		if( found)
		{
			[cell setTextColor: [NSColor blackColor]];
			[cell setFont:[NSFont boldSystemFontOfSize:12]];
		}
		else
		{
			[cell setTextColor: [NSColor grayColor]];
			[cell setFont:[NSFont systemFontOfSize:12]];
		}
	}
	else
	{
		[cell setTextColor: [NSColor blackColor]];
		[cell setFont:[NSFont systemFontOfSize:12]];
	}
	[cell setLineBreakMode: NSLineBreakByTruncatingMiddle];
}

- (void) traverse: (NSXMLNode*) node string:(NSMutableString*) string
{
	int i;
	
	for( i = 0; i < [node childCount]; i++)
	{
		if( [[node childAtIndex: i] stringValue] && [[node childAtIndex: i] childCount] == 0)
		{
			if( [string length]) [string appendFormat:@"\\%@", [[node childAtIndex: i] stringValue]];
			else [string appendString: [[node childAtIndex: i] stringValue]];
		}
		
		if( [[node childAtIndex: i] childCount])
			[self traverse: [node childAtIndex: i] string: string];
	}
}

- (NSString*) stringsSeparatedForNode:(NSXMLNode*) node
{
	if( [node childCount] == 0) return [node valueForKey:@"stringValue"];
	
	NSMutableString	*string = [NSMutableString string];
	
	[self traverse: node string: string];
	
	return string;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    NSString    *identifier = [tableColumn identifier];
	if ([identifier isEqualToString:@"attributeTag"])
	{
		if( [item attributeForName:@"group"] && [item attributeForName:@"element"])
			return [NSString stringWithFormat:@"%@,%@", [[item attributeForName:@"group"] stringValue], [[item attributeForName:@"element"] stringValue]];
	}
	else if( [identifier isEqualToString:@"stringValue"])
	{
		if( [outlineView rowForItem: item] != 0)
			return [self stringsSeparatedForNode: item];
	}
	else return [item valueForKey:identifier];
		
	return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if( [[tableColumn identifier] isEqualToString: @"stringValue"])
	{
		if( [item attributeForName:@"group"] && [item attributeForName:@"element"])
		{
			if( [[[item attributeForName:@"group"] stringValue] intValue] != 0)	//[[[item attributeForName:@"group"] stringValue] intValue] != 2 && 
			{
				return YES;
			}
		}
		else if( [[[[item children] objectAtIndex: 0] children] count] == 0)	// A multiple value
		{
			return YES;
		}
		else NSLog( @"Sequence");
		
		return NO;
	}
	else
		return NO;
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if( [[tableColumn identifier] isEqualToString: @"stringValue"])
	{
		NSMutableString*	copyString = [NSMutableString string];
		int					index;
		NSMutableArray		*groupsAndElements = [NSMutableArray array];
		
		if( [table rowForItem: item] > 0)
		{
			NSString	*path = [self getPath: item];
			
			if( [[item attributeForName:@"group"] stringValue] && [[item attributeForName:@"element"] stringValue])
			{
				[groupsAndElements addObjectsFromArray: [NSArray arrayWithObjects: @"-i", [NSString stringWithFormat: @"%@=%@", path, object], 0L]];
			}
			else // A multiple value or a sequence, not an element
			{
				if( [[[[item children] objectAtIndex: 0] children] count] == 0)
				{
					int index = [[path substringWithRange: NSMakeRange( [path length]-2, 1)] intValue];
					
					path = [path substringToIndex: [path length]-3];
					
					NSLog( path);
					NSLog( @"%d", index);
					
					NSMutableArray	*values = [NSMutableArray arrayWithArray: [[self stringsSeparatedForNode: [item parent]] componentsSeparatedByString:@"\\"]];
					
					[values replaceObjectAtIndex: index withObject: object];
					
					[groupsAndElements addObjectsFromArray: [NSArray arrayWithObjects: @"-i", [NSString stringWithFormat: @"%@=%@", path, [values componentsJoinedByString:@"\\"]], 0L]];
				}
				else
				{
					NSLog( @"A sequence");
				}
			}
		}
		
		if( [groupsAndElements count])
		{
			NSMutableArray	*params = [NSMutableArray arrayWithObjects:@"dcmodify", @"--verbose", @"--ignore-errors", 0L];
			
			[params addObjectsFromArray:  groupsAndElements];
			
			NSArray	*files = [self arrayOfFiles];
			
			if( files)
			{
				[params addObjectsFromArray: files];
				
				WaitRendering		*wait = 0L;
				if( [files count] > 1)
				{
					wait = [[WaitRendering alloc] init: NSLocalizedString(@"Updating Files...", nil)];
					[wait showWindow:self];
				}
				
				[self modifyDicom: params];
				
				[wait close];
				[wait release];
				wait = 0L;
				
				[self reload: self];
			}
		}
	}
}

- (void)keyDown:(NSEvent *)event
{
	NSLog( @"keyDown");
	
	unichar				c = [[event characters] characterAtIndex:0];
	
	if( c == NSDeleteFunctionKey || c == NSDeleteCharacter || c == NSBackspaceCharacter)
	{
		NSIndexSet*			selectedRowIndexes = [table selectedRowIndexes];
		NSMutableString*	copyString = [NSMutableString string];
		int					index;
		NSMutableArray		*groupsAndElements = [NSMutableArray array];
		
		for (index = [selectedRowIndexes firstIndex]; 1+[selectedRowIndexes lastIndex] != index; ++index)
		{
		   if ([selectedRowIndexes containsIndex:index])
		   {
				id	item = [table itemAtRow: index];
				
				if( index > 0)
				{
					NSString	*path = [self getPath: item];
					
					if( [[item attributeForName:@"group"] stringValue] && [[item attributeForName:@"element"] stringValue])
					{
						[groupsAndElements addObjectsFromArray: [NSArray arrayWithObjects: @"-e", path, 0L]];
					}
					else // A multiple value or a sequence, not an element
					{
						if( [[[[item children] objectAtIndex: 0] children] count] == 0)
						{
							int index = [[path substringWithRange: NSMakeRange( [path length]-2, 1)] intValue];
							
							path = [path substringToIndex: [path length]-3];
							
							NSLog( path);
							NSLog( @"%d", index);
							
							NSMutableArray	*values = [NSMutableArray arrayWithArray: [[self stringsSeparatedForNode: [item parent]] componentsSeparatedByString:@"\\"]];
							
							[values removeObjectAtIndex: index];
							
							[groupsAndElements addObjectsFromArray: [NSArray arrayWithObjects: @"-i", [NSString stringWithFormat: @"%@=%@", path, [values componentsJoinedByString:@"\\"]], 0L]];
						}
						else
						{
							NSLog( @"A sequence");
							
							NSString	*path = [self getPath: (NSXMLElement*) [item parent]];
							[groupsAndElements addObjectsFromArray: [NSArray arrayWithObjects: @"-e", path, 0L]];
						}
					}
				}
			}
		}
		
		if( [groupsAndElements count])
		{
			NSMutableArray	*params = [NSMutableArray arrayWithObjects:@"dcmodify", @"--verbose", @"--ignore-errors", 0L];
			
			[params addObjectsFromArray:  groupsAndElements];
			
			NSArray	*files = [self arrayOfFiles];
			
			if( files)
			{
				[params addObjectsFromArray: files];
				
				WaitRendering		*wait = 0L;
				if( [files count] > 1)
				{
					wait = [[WaitRendering alloc] init: NSLocalizedString(@"Updating Files...", nil)];
					[wait showWindow:self];
				}
				
				[self modifyDicom: params];
				
				[wait close];
				[wait release];
				wait = 0L;
				
				[self reload: self];
			}
		}
	}
	else [super keyDown: event];
}

- (void)copy:(id)sender
{
	NSIndexSet*			selectedRowIndexes = [table selectedRowIndexes];
	NSMutableString*	copyString = [NSMutableString string];
	int					index;
	
	for (index = [selectedRowIndexes firstIndex]; 1+[selectedRowIndexes lastIndex] != index; ++index)
	{
       if ([selectedRowIndexes containsIndex:index])
	   {
			id	item = [table itemAtRow: index];
			
			if( [copyString length]) [copyString appendString:@"\r"];
			
			if( [[item attributeForName:@"group"] stringValue] && [[item attributeForName:@"element"] stringValue])
				[copyString appendFormat:@"%@ (%@,%@) %@", [item valueForKey: @"name"], [[item attributeForName:@"group"] stringValue], [[item attributeForName:@"element"] stringValue], [self stringsSeparatedForNode: item]];
			else
				[copyString appendFormat:@"%@ %@", [item valueForKey: @"name"], [self stringsSeparatedForNode: item]];
			
			NSLog( [item description]);
			
			NSLog( @"---");
			
			NSLog( [item valueForKey: @"name"]);
			
			NSLog( [[item attributeForName:@"group"] stringValue]);
			NSLog( [[item attributeForName:@"element"] stringValue]);
			
			NSLog( [[item attributeForName:@"attributeTag"] stringValue]);
			
			NSLog( [item valueForKey: @"stringValue"]);
			
			NSLog( @"---");
			
			NSLog( [self stringsSeparatedForNode: item]);
	   }
	}
	
	NSPasteboard	*pb = [NSPasteboard generalPasteboard];
	[pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
	[pb setString: copyString forType:NSStringPboardType];
}

// ============================================================
// NSToolbar Related Methods
// ============================================================

- (void) setupToolbar {
    // Create a new toolbar instance, and attach it to our document window 
    toolbar = [[NSToolbar alloc] initWithIdentifier: XMLToolbarIdentifier];
    
    // Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults 
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
//    [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
    
    // We are the delegate
    [toolbar setDelegate: self];
    
    // Attach the toolbar to the document window 
    [[self window] setToolbar: toolbar];
	[[self window] setShowsToolbarButton:NO];
	[[[self window] toolbar] setVisible: YES];
    
//    [window makeKeyAndOrderFront:nil];
}

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {
    // Required delegate method:  Given an item identifier, this method returns an item 
    // The toolbar will use this method to obtain toolbar items that can be displayed in the customization sheet, or in the toolbar itself 
    NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier: itemIdent];
    
    if ([itemIdent isEqual: ExportToolbarItemIdentifier]) {
		[toolbarItem setLabel: NSLocalizedString(@"Export XML",nil)];
		[toolbarItem setPaletteLabel: NSLocalizedString(@"Export XML",nil)];
			[toolbarItem setToolTip: NSLocalizedString(@"Export these XML Data in a XML File",nil)];
		[toolbarItem setImage: [NSImage imageNamed: ExportToolbarItemIdentifier]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(exportXML:)];
    }
	else if ([itemIdent isEqual: SearchToolbarItemIdentifier])
	{
		[toolbarItem setLabel: NSLocalizedString(@"Search", nil)];
		[toolbarItem setPaletteLabel: NSLocalizedString(@"Search", nil)];
		[toolbarItem setToolTip: NSLocalizedString(@"Search", nil)];
		
		[toolbarItem setView: searchView];
		[toolbarItem setMinSize:NSMakeSize(NSWidth([searchView frame]), NSHeight([searchView frame]))];
		[toolbarItem setMaxSize:NSMakeSize(NSWidth([searchView frame]), NSHeight([searchView frame]))];
    }
	else if ([itemIdent isEqual: ExportTextToolbarItemIdentifier]) {       
		[toolbarItem setLabel: NSLocalizedString(@"Export Text", 0L)];
		[toolbarItem setPaletteLabel: NSLocalizedString(@"Export Text", 0L)];
		[toolbarItem setToolTip: NSLocalizedString(@"Export these XML Data in a Text File", 0L)];
		[toolbarItem setImage: [NSImage imageNamed: ExportToolbarItemIdentifier]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(exportText:)];
    }
	else if ([itemIdent isEqual: ExpandAllItemsToolbarItemIdentifier]) {
		[toolbarItem setLabel: NSLocalizedString(@"Expand All", 0L)];
		[toolbarItem setPaletteLabel: NSLocalizedString(@"Expand All Items", 0L)];
		[toolbarItem setToolTip: NSLocalizedString(@"Expand All Items", 0L)];
		[toolbarItem setImage: [NSImage imageNamed: ExpandAllItemsToolbarItemIdentifier]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(deepExpandAllItems:)];
    }
	else if ([itemIdent isEqual: CollapseAllItemsToolbarItemIdentifier]) {
		[toolbarItem setLabel: NSLocalizedString(@"Collapse All", 0L)];
		[toolbarItem setPaletteLabel: NSLocalizedString(@"Collapse All Items", 0L)];
		[toolbarItem setToolTip: NSLocalizedString(@"Collapse All Items", 0L)];
		[toolbarItem setImage: [NSImage imageNamed: CollapseAllItemsToolbarItemIdentifier]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(deepCollapseAllItems:)];
    }
    else {
	// itemIdent refered to a toolbar item that is not provide or supported by us or cocoa 
	// Returning nil will inform the toolbar this kind of item is not supported 
	toolbarItem = nil;
    }
     return [toolbarItem autorelease];
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar {
    // Required delegate method:  Returns the ordered list of items to be shown in the toolbar by default    
    // If during the toolbar's initialization, no overriding values are found in the user defaults, or if the
    // user chooses to revert to the default items this set will be used 
    return [NSArray arrayWithObjects:	ExportToolbarItemIdentifier, 
										ExportTextToolbarItemIdentifier,
										ExpandAllItemsToolbarItemIdentifier,
										CollapseAllItemsToolbarItemIdentifier,
										NSToolbarFlexibleSpaceItemIdentifier,
										SearchToolbarItemIdentifier,
										nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar {
    // Required delegate method:  Returns the list of all allowed items by identifier.  By default, the toolbar 
    // does not assume any items are allowed, even the separator.  So, every allowed item must be explicitly listed   
    // The set of allowed items is used to construct the customization palette 
    return [NSArray arrayWithObjects: 	NSToolbarCustomizeToolbarItemIdentifier,
										NSToolbarFlexibleSpaceItemIdentifier,
										NSToolbarSpaceItemIdentifier,
										NSToolbarSeparatorItemIdentifier,
										ExportToolbarItemIdentifier,
										ExportTextToolbarItemIdentifier, 
										ExpandAllItemsToolbarItemIdentifier,
										CollapseAllItemsToolbarItemIdentifier,
										SearchToolbarItemIdentifier,
										nil];
}

- (void) toolbarWillAddItem: (NSNotification *) notif {
    // Optional delegate method:  Before an new item is added to the toolbar, this notification is posted.
    // This is the best place to notice a new item is going into the toolbar.  For instance, if you need to 
    // cache a reference to the toolbar item or need to set up some initial state, this is the best place 
    // to do it.  The notification object is the toolbar to which the item is being added.  The item being 
    // added is found by referencing the @"item" key in the userInfo 
    NSToolbarItem *addedItem = [[notif userInfo] objectForKey: @"item"];
	
	[addedItem retain];
}  

- (void) toolbarDidRemoveItem: (NSNotification *) notif {
    // Optional delegate method:  After an item is removed from a toolbar, this notification is sent.   This allows 
    // the chance to tear down information related to the item that may have been cached.   The notification object
    // is the toolbar from which the item is being removed.  The item being added is found by referencing the @"item"
    // key in the userInfo 
    NSToolbarItem *removedItem = [[notif userInfo] objectForKey: @"item"];
	
	[removedItem release];
	
/*    if (removedItem==activeSearchItem) {
	[activeSearchItem autorelease];
	activeSearchItem = nil;    
    }*/
}

- (BOOL) validateToolbarItem: (NSToolbarItem *) toolbarItem
{
    // Optional method:  This message is sent to us since we are the target of some toolbar item actions 
    // (for example:  of the save items action) 
    BOOL enable = YES;
 //   if ([[toolbarItem itemIdentifier] isEqual: ImportToolbarItemIdentifier]) {
	// We will return YES (ie  the button is enabled) only when the document is dirty and needs saving 
//	enable = YES;
 // }	
    return enable;
}

- (void) expandAllItems: (id) sender
{
	[self expandAll:NO];
}

- (void) deepExpandAllItems: (id) sender
{
	[self expandAll:YES];
}

- (void) expandAll: (BOOL) deep
{
	int i;
	for(i=0 ; i<[table numberOfRows] ; i++)
	{
		[table expandItem:[table itemAtRow:i] expandChildren:deep];
	}
}

- (void) collapseAllItems: (id) sender
{
	[self collapseAll:NO];
}

- (void) deepCollapseAllItems: (id) sender
{
	[self collapseAll:YES];
}

- (void) collapseAll: (BOOL) deep
{
	int i;
	for(i=1 ; i<[table numberOfRows]; i++) // starting from 1, so the DICOMObject is not collapsed
	{
		[table collapseItem:[table itemAtRow:i] collapseChildren:deep];
	}
}

@end
