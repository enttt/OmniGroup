// Copyright 2010-2012 The Omni Group. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniUI/OUIFontInspectorSlice.h>

#import <OmniUI/OUIInspector.h>
#import <OmniUI/OUIInspectorTextWell.h>
#import <OmniUI/OUIInspectorStepperButton.h>
#import <OmniUI/OUIFontInspectorPane.h>

#import "OUIFontUtilities.h"

#import <OmniAppKit/OAFontDescriptor.h>
#import <OmniBase/OmniBase.h>

RCS_ID("$Id$");

@interface OUIFontInspectorSlice (/*Private*/)
- (IBAction)_showFontFamilies:(id)sender;
- (NSString *)_formatFontSize:(CGFloat)fontSize;
@end

@implementation OUIFontInspectorSlice

@synthesize fontFamilyTextWell = _fontFamilyTextWell;
@synthesize fontSizeDecreaseStepperButton = _fontSizeDecreaseStepperButton;
@synthesize fontSizeIncreaseStepperButton = _fontSizeIncreaseStepperButton;
@synthesize fontSizeTextWell = _fontSizeTextWell;
@synthesize fontFacesPane = _fontFacesPane;

// TODO: should these be ivars?
static const CGFloat kMinimumFontSize = 2;
static const CGFloat kMaximumFontSize = 128;
static const CGFloat kPrecision = 1000.0f;
    // Font size will be rounded to nearest 1.0f/kPrecision
static const NSString *kDigitsPrecision = @"###";
    // Number of hashes here should match the number of digits after the decimal point in the decimal representation of  1.0f/kPrecision.

static CGFloat _normalizeFontSize(CGFloat fontSize)
{
    CGFloat result = fontSize;

    result = rint(result * kPrecision) / kPrecision;
    
    if (result < kMinimumFontSize)
        result = kMinimumFontSize;
    else if (result > kMaximumFontSize)
        result = kMaximumFontSize;
    
    return result;
}

static void _setFontSize(OUIFontInspectorSlice *self, CGFloat fontSize, BOOL relative)
{
    OUIInspector *inspector = self.inspector;
    [inspector willBeginChangingInspectedObjects];
    {
        for (id <OUIFontInspection> object in self.appropriateObjectsForInspection) {
            OAFontDescriptor *fontDescriptor = [object fontDescriptorForInspectorSlice:self];
            if (fontDescriptor) {
                CGFloat newSize = relative? ( [fontDescriptor size] + fontSize ) : fontSize;
                newSize = _normalizeFontSize(newSize);
                fontDescriptor = [fontDescriptor newFontDescriptorWithSize:newSize];
            } else {
                UIFont *font = [UIFont systemFontOfSize:[UIFont labelFontSize]];
                CGFloat newSize = relative? ( font.pointSize + fontSize ) : fontSize;
                newSize = _normalizeFontSize(newSize);
                fontDescriptor = [[OAFontDescriptor alloc] initWithFamily:font.familyName size:newSize];
            }
            [object setFontDescriptor:fontDescriptor fromInspectorSlice:self];
            [fontDescriptor release];
        }
    }
    [inspector didEndChangingInspectedObjects];
    
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.fontSizeTextWell.accessibilityValue);
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
        return nil;
    
    NSString *baseFormat = @"#,##0";
    
    _wholeNumberFormatter = [[NSNumberFormatter alloc] init];
    [_wholeNumberFormatter setPositiveFormat:baseFormat];
    
    NSString *decimalFormat = [[NSString alloc] initWithFormat:@"%@.%@", baseFormat, kDigitsPrecision];
    
    _fractionalNumberFormatter = [[NSNumberFormatter alloc] init];
    [_fractionalNumberFormatter setPositiveFormat:decimalFormat];
    
    [decimalFormat release];
    
    return self;
}

- (void)dealloc;
{
    [_fontFamilyTextWell release];
    
    [_fontSizeDecreaseStepperButton release];
    [_fontSizeIncreaseStepperButton release];
    [_fontSizeTextWell release];
    [_fontFacesPane release];
    [_wholeNumberFormatter release];
    [_fractionalNumberFormatter release];
    [super dealloc];
}

- (IBAction)increaseFontSize:(id)sender;
{
    [_fontSizeTextWell endEditing:YES/*force*/];
    _setFontSize(self, 1, YES /* relative */);
}

- (IBAction)decreaseFontSize:(id)sender;
{
    [_fontSizeTextWell endEditing:YES/*force*/];
    _setFontSize(self, -1, YES /* relative */);
}

- (IBAction)fontSizeTextWellAction:(OUIInspectorTextWell *)sender;
{
    _setFontSize(self, [[sender text] floatValue], NO /* not relative */);
}

- (void)showFacesForFamilyBaseFont:(UIFont *)font;
{
    _fontFacesPane.showFacesOfFont = font;
    _fontFacesPane.title = OUIDisplayNameForFont(font, YES/*useFamilyName*/);

    [self.inspector pushPane:_fontFacesPane];
}

- (OUIFontInspectorSliceFontDisplay)fontNameDisplayForFontDescriptor:(OAFontDescriptor *)fontDescriptor;
{
    OUIFontInspectorSliceFontDisplay display;

    CGFloat fontSize = [OUIInspectorTextWell fontSize];

    CTFontRef font = [fontDescriptor font];
    OBASSERT(font);
    
    if (font) {
        CFStringRef familyName = CTFontCopyFamilyName(font);
        OBASSERT(familyName);
        CFStringRef postscriptName = CTFontCopyPostScriptName(font);
        OBASSERT(postscriptName);
        CFStringRef displayName = CTFontCopyDisplayName(font);
        OBASSERT(displayName);
        
        
        // Using the whole display name gets kinda long in the fixed space we have. Can swap which line is commented below to try it out.
        display.text = OUIIsBaseFontNameForFamily((NSString *)postscriptName, (id)familyName) ? (id)familyName : (id)displayName;
        //display.text = (id)familyName;
        display.font = postscriptName ? [UIFont fontWithName:(id)postscriptName size:fontSize] : [UIFont systemFontOfSize:fontSize];
        
        if (familyName)
            CFRelease(familyName);
        if (postscriptName)
            CFRelease(postscriptName);
        if (displayName)
            CFRelease(displayName);
    } else {
        display.text = @"???";
        display.font = nil;
    }
    
    return display;
}

- (OUIFontInspectorSliceFontDisplay)fontNameDisplayForFontDescriptors:(NSArray *)fontDescriptors;
{
//    CGFloat fontSize = [OUIInspectorTextWell fontSize];
    
    OUIFontInspectorSliceFontDisplay display;
    
    switch ([fontDescriptors count]) {
        case 0:
            display.text = NSLocalizedStringFromTableInBundle(@"No Selection", @"OUIInspectors", OMNI_BUNDLE, @"popover inspector label title for no selected objects");
            display.font = [OUIInspector labelFont];
            break;
        case 1:
            display = [self fontNameDisplayForFontDescriptor:[fontDescriptors objectAtIndex:0]];
            break;
        default:
            display.text = NSLocalizedStringFromTableInBundle(@"Multiple Selection", @"OUIInspectors", OMNI_BUNDLE, @"popover inspector label title for mulitple selection");
            display.font = [OUIInspector labelFont];
            break;
    }
    
    return display;
}

- (void)updateFontSizeTextWellForFontSizes:(NSArray *)fontSizes extent:(OFExtent)fontSizeExtent;
{
    CGFloat fontSize = [OUIInspectorTextWell fontSize];
    _fontSizeTextWell.font = [UIFont systemFontOfSize:fontSize];

    switch ([fontSizes count]) {
        case 0:
            OBASSERT_NOT_REACHED("why are we even visible?");
            // leave value where ever it was
            // disable controls? 
            _fontSizeTextWell.text = nil;
            break;
        case 1:
            _fontSizeTextWell.text = [self _formatFontSize:OFExtentMin(fontSizeExtent)];
            break;
        default:
            {
                CGFloat minSize = floor(OFExtentMin(fontSizeExtent));
                CGFloat maxSize = ceil(OFExtentMax(fontSizeExtent));

                // If either size is fractional, slap a ~ on the front.
                NSString *format = nil;
                if (minSize != OFExtentMin(fontSizeExtent) || maxSize != OFExtentMax(fontSizeExtent)) 
                    format = @"~ %@\u2013%@";  /* tilde, two numbers, en-dash */
                else
                    format = @"%@\u2013%@";  /* two numbers, en-dash */
                _fontSizeTextWell.text = [NSString stringWithFormat:format, [self _formatFontSize:minSize], [self _formatFontSize:maxSize]];
            }
            break;
    }
}

#pragma mark -
#pragma mark OUIInspectorSlice subclass

- (BOOL)isAppropriateForInspectedObject:(id)object;
{
    return [object shouldBeInspectedByInspectorSlice:self protocol:@protocol(OUIFontInspection)];
}

static void _configureTextWellDisplay(OUIInspectorTextWell *textWell, OUIFontInspectorSliceFontDisplay display)
{
    textWell.text = display.text;
    textWell.font = display.font;
}

- (void)updateInterfaceFromInspectedObjects:(OUIInspectorUpdateReason)reason;
{
    [super updateInterfaceFromInspectedObjects:reason];
    
    OUIFontSelection selection = OUICollectFontSelection(self, self.appropriateObjectsForInspection);
    
    _configureTextWellDisplay(_fontFamilyTextWell, [self fontNameDisplayForFontDescriptors:selection.fontDescriptors]);
    
    [self updateFontSizeTextWellForFontSizes:selection.fontSizes extent:selection.fontSizeExtent];
}

#pragma mark -
#pragma mark UIViewController subclass

- (void)viewDidLoad;
{
    [super viewDidLoad];

    _fontFamilyTextWell.style = OUIInspectorTextWellStyleSeparateLabelAndText;
    _fontFamilyTextWell.backgroundType = OUIInspectorWellBackgroundTypeButton;
    _fontFamilyTextWell.label = NSLocalizedStringFromTableInBundle(@"Font", @"OUIInspectors", OMNI_BUNDLE, @"Title for the font family list in the inspector");
    _fontFamilyTextWell.labelFont = [[_fontFamilyTextWell class] defaultLabelFont];
    _fontFamilyTextWell.cornerType = OUIInspectorWellCornerTypeLargeRadius;
    
    [_fontFamilyTextWell setNavigationTarget:self action:@selector(_showFontFamilies:)];
    [(UIImageView *)_fontFamilyTextWell.rightView setHighlightedImage:[OUIInspectorWell navigationArrowImageHighlighted]];
    
    _fontSizeDecreaseStepperButton.title = @"A";
    _fontSizeDecreaseStepperButton.titleFont = [UIFont boldSystemFontOfSize:14];
    _fontSizeDecreaseStepperButton.titleColor = [UIColor whiteColor];
    _fontSizeDecreaseStepperButton.flipped = YES;
    _fontSizeDecreaseStepperButton.accessibilityLabel = NSLocalizedStringFromTableInBundle(@"Font smaller", @"OUIInspectors", OMNI_BUNDLE, @"Decrement font size button accessibility label");

    _fontSizeIncreaseStepperButton.title = @"A";
    _fontSizeIncreaseStepperButton.titleFont = [UIFont boldSystemFontOfSize:32];
    _fontSizeIncreaseStepperButton.titleColor = [UIColor whiteColor];
    _fontSizeIncreaseStepperButton.accessibilityLabel = NSLocalizedStringFromTableInBundle(@"Font bigger", @"OUIInspectors", OMNI_BUNDLE, @"Increment font size button accessibility label");

    CGFloat fontSize = [OUIInspectorTextWell fontSize];
    _fontSizeTextWell.font = [UIFont boldSystemFontOfSize:fontSize];
    _fontSizeTextWell.label = NSLocalizedStringFromTableInBundle(@"%@ points", @"OUIInspectors", OMNI_BUNDLE, @"font size label format string in points");
    _fontSizeTextWell.labelFont = [UIFont systemFontOfSize:fontSize];
    _fontSizeTextWell.editable = YES;
    [_fontSizeTextWell setKeyboardType:UIKeyboardTypeNumberPad];
    _fontSizeTextWell.accessibilityLabel = @"Font size";

    // Superclass does this for the family detail.
    _fontFacesPane.parentSlice = self;
}

#pragma mark -
#pragma mark Private

- (IBAction)_showFontFamilies:(id)sender;
{
    OUIFontInspectorPane *familyPane = (OUIFontInspectorPane *)self.detailPane;
    OBPRECONDITION(familyPane);
    
    familyPane.title = NSLocalizedStringFromTableInBundle(@"Font", @"OUIInspectors", OMNI_BUNDLE, @"Title for the font family list in the inspector");
    familyPane.showFacesOfFont = nil; // shows families
    
    [self.inspector pushPane:familyPane];
}

- (NSString *)_formatFontSize:(CGFloat)fontSize;
{
    CGFloat displaySize = _normalizeFontSize(fontSize);
    NSNumberFormatter *formatter = nil;
    if (rint(displaySize) != displaySize)
        formatter = _fractionalNumberFormatter;
    else
        formatter = _wholeNumberFormatter;
    
    return [formatter stringFromNumber:[NSNumber numberWithDouble:displaySize]];
}

@end

