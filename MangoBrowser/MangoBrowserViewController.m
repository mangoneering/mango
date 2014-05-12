//
//  MangoBrowserView.m
//  Mango
//
//  Created by Juan Carlos Moreno on 4/13/14.
//  Copyright (c) 2014 Juan Carlos Moreno. All rights reserved.
//

#import "MangoBrowserViewController.h"

@implementation MangoBrowserViewController

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self == [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        [[self view] setAutoresizesSubviews: YES];
        [[self view] setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
        [self setAutoRefresh:YES];
        [self setQueryLimit:@(10)];
        self.dbData = @[];
        [[self filterPredicateEditor] addRow:self];
    }

    return self;
}


-(BOOL) shouldAutoRefresh
{
    return [self autoRefresh];
}

#pragma mark - MangoPlugin

-(void) refreshDataFromDB: (NSString *) db withCollection: (NSString *) col andDataManager: (MangoDataManager *) mgr
{
    if ([self shouldAutoRefresh])
    {
        if ([[col stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] != 0)
        {
            [[self progressBar] startAnimation:self];
            [[self progressBar] setHidden: NO];
            [[[self progressBar] animator] setAlphaValue:1];
            [[self messageInfo] setStringValue: [NSString stringWithFormat:@"Loading %@.%@", db, col]];
            NSDate *start = [NSDate date];
            NSMutableDictionary *options = [@{} mutableCopy];
            
            if (![[self queryLimit] isEqualToNumber:@(0)])
            {
                NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
                [f setNumberStyle:NSNumberFormatterDecimalStyle];
                NSNumber * limit = [f numberFromString:[[self queryLimit] stringValue]];
                options[@"limit"] = limit;
            }
            
            NSArray *res = [[mgr ConnectionManager] queryNameSpace: [NSString stringWithFormat:@"%@.%@", db, col ] withOptions: options];
            //res = [self reformatQueryResults:res];
            NSWindowController *wc = [[[self view] window] windowController];
            SEL dmSelector = NSSelectorFromString(@"dataManager");
            if ([wc respondsToSelector:dmSelector])
            {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                MangoDataManager *dm = [wc performSelector:dmSelector];
#pragma clang diagnostic pop
                res = [dm convertMultipleJSONDocumentsToMango: res];
                [self setDbData:res];
                [[self outlineView] reloadData];
            }
            NSTimeInterval timeInterval = [start timeIntervalSinceNow];
            [[self progressBar] stopAnimation:self];
            [[[self progressBar] animator] setAlphaValue:0.0];
            [[self messageInfo] setStringValue: [NSString stringWithFormat:@"Loaded %@.%@ in %f", db, col, timeInterval]];
        }
        else
        {
            [[self messageInfo] setStringValue: @""];
            [self setDbData:@[]];
            [[self outlineView] reloadData];
        }
    }
}


- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell*)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    //NSLog(@"%@ %@", NSStringFromSelector(_cmd), item);
}

- (NSCell*) outlineView:(NSOutlineView*) outlineView dataCellForTableColumn:(NSTableColumn*) tableColumn item:(id) item
{
    NSDictionary *rObj = [item representedObject];
    
    if (rObj && [rObj objectForKey:@"Type"])
    {
        NSCell *cell;
        if ([[outlineView tableColumns] objectAtIndex:0] == tableColumn)
        {
            // Key
            MangoBrowserKeyCell *_cell = [[MangoBrowserKeyCell alloc] init];
            
            NSString *type = [rObj objectForKey:@"Type"];
            if ( type && [[rObj objectForKey:@"Type"] isEqualToString:@"ObjectID"])
            {
                if([rObj objectForKey:@"Modified"])
                {
                    //NSLog(@"Modified %@", type);
                    [_cell setModifiedBadge:[NSNumber numberWithBool:YES]];
                }
            }
            [_cell setDataType: type];
            
            cell = _cell;
        }
        else if ([[outlineView tableColumns] objectAtIndex:1] == tableColumn)
        {
            MangoBrowserValueCell *_cell = [[MangoBrowserValueCell alloc]init];
            [_cell setDataType:[rObj objectForKey:@"Type"]];
            cell = _cell;
        }
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

        [nc removeObserver:self name:NSControlTextDidEndEditingNotification object:[self outlineView]];
        [nc addObserver:self selector:@selector(endEditNotification:)   name:NSControlTextDidEndEditingNotification object:[self outlineView]];
        
        return cell;
        
    }
    
    return [tableColumn dataCell];
}

-(void) endEditNotification:(NSNotification *) notification
{

    NSInteger row = [[self outlineView] selectedRow];
    NSTreeNode *node = [[self outlineView] itemAtRow:row];
    NSTreeNode *parent = [node parentNode];
    
    while (parent)
    {
        NSTreeNode *newParent = [parent parentNode];
        
        if (newParent)
        {
            node = parent;
            parent = newParent;
            
        }
        else
        {
            break;
        }
    }
    
    NSMutableDictionary *rObj = [[node representedObject] mutableCopy];
    NSString *type = [rObj valueForKey:@"Type"];
    NSString *value = [rObj valueForKey:@"Value"];
    [rObj setValue:[NSNumber numberWithBool:YES] forKey:@"Modified"];
    NSMutableArray *dbData = [[self dbData] mutableCopy];
    
    if ([type isEqualToString:@"ObjectID"])
    {
        NSInteger index = -1;
        for (NSDictionary *item in [self dbData])
        {
            index +=1;
            NSString *objId = [item valueForKey:@"Value"];
            if ([objId isEqualToString:value])
            {
                break;
            }
        }
        
        if(index > -1)
        {
            [dbData replaceObjectAtIndex:index withObject:rObj];
            [self setDbData: dbData];
            [[self outlineView] setNeedsDisplay: YES];
        }
    }
}


- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
    return 25;
}

- (IBAction)mapReduceButtonWasPressed:(id)sender
{
    [self togglePopOver:[self mapReducePopover] withSender:sender];
}

- (IBAction)filterButtonWasPressed:(id)sender
{
    [self togglePopOver:[self filterPopover] withSender:sender];
}

- (IBAction)runQueryButtonWasPressed:(id)sender
{
    
}

- (IBAction)indicesButtonWasPressed:(id)sender
{
    [self togglePopOver:[self indicesPopover] withSender:sender];
}

-(void) togglePopOver: (NSPopover *) popover withSender: (id) sender
{
    if ([popover isShown])
    {
        [popover close];
    }
    else
    {
        [popover showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMaxYEdge];
    }
}


-(void) setSimpleMode
{
    NSArray *subViews = [[self toolBar] subviews];
    
    for(NSView *subview in subViews)
    {
        [subview setHidden:YES];
    }
    [self setAutoRefresh:NO];
}


@end
