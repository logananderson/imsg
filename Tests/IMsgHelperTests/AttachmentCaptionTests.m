#import <Foundation/Foundation.h>

static Class captionTestClass(NSString *name) {
    if ([name hasPrefix:@"IM"] || [name hasPrefix:@"IDS"]) return Nil;
    return NSClassFromString(name);
}
#define NSClassFromString captionTestClass
#import "../../Sources/IMsgHelper/IMsgInjected.m"
#undef NSClassFromString

static NSUInteger failures;
static void check(BOOL condition, NSString *message) {
    if (!condition) { fprintf(stderr, "FAIL: %s\n", message.UTF8String); failures++; }
}

int main(void) {
    @autoreleasepool {
        NSArray *formatting = @[@{@"start": @0, @"length": @4, @"styles": @[@"bold"]}];
        for (NSArray *styles in @[@[], formatting]) {
            for (NSString *caption in @[@"Here is the file", @"Here\nis the file\n", @"Here 👋 café"]) {
                NSAttributedString *body = buildCaptionedAttachmentAttributed(
                    caption, styles, @"synthetic-transfer", @"fixture.txt", 3);
                check([body.string isEqualToString:[caption stringByAppendingString:@"\uFFFC"]],
                      @"Caption preserves exactly the supplied text before the attachment");
                NSRange textRange;
                NSNumber *textPart = [body attribute:@"__kIMMessagePartAttributeName"
                    atIndex:0 longestEffectiveRange:&textRange inRange:NSMakeRange(0, body.length)];
                check([textPart isEqual:@3] && NSEqualRanges(textRange, NSMakeRange(0, caption.length)),
                      @"Caption has its own part with no extra newline");
                NSDictionary *attachment = [body attributesAtIndex:body.length - 1 effectiveRange:NULL];
                check([attachment[@"__kIMMessagePartAttributeName"] isEqual:@4],
                      @"Attachment follows the caption as the next message part");
                check([attachment[@"__kIMFileTransferGUIDAttributeName"] isEqual:@"synthetic-transfer"]
                      && [attachment[@"__kIMFilenameAttributeName"] isEqual:@"fixture.txt"],
                      @"Attachment retains its transfer and filename");
                check(attachment[@"__kIMTextBoldAttributeName"] == nil,
                      @"Caption formatting does not leak onto the attachment");
                if (styles.count && NSProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 15) {
                    NSRange boldRange;
                    NSNumber *bold = [body attribute:@"__kIMTextBoldAttributeName"
                        atIndex:0 effectiveRange:&boldRange];
                    check([bold isEqual:@1] && NSEqualRanges(boldRange, NSMakeRange(0, 4)),
                          @"Caption retains the supplied formatting range");
                }
            }
        }
        for (id caption in @[@"", NSNull.null]) {
            NSAttributedString *body = buildCaptionedAttachmentAttributed(
                caption == NSNull.null ? nil : caption, formatting,
                @"synthetic-transfer", @"fixture.txt", 3);
            check([body.string isEqualToString:@"\uFFFC"], @"No caption creates only the attachment");
            check([[body attribute:@"__kIMMessagePartAttributeName" atIndex:0 effectiveRange:NULL] isEqual:@3],
                  @"No caption preserves the requested attachment part index");
        }
    }
    fprintf(stderr, "AttachmentCaptionTests: %lu failures\n", (unsigned long)failures);
    return failures ? 1 : 0;
}
