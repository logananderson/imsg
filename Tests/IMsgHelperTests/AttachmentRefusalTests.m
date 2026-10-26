#import <Foundation/Foundation.h>
#import "../../Sources/IMsgHelper/IMsgInjected.m"

static NSUInteger failures;

static void check(BOOL condition, NSString *message) {
    if (condition) return;
    fprintf(stderr, "FAIL: %s\n", message.UTF8String);
    failures++;
}

static void checkNotStarted(NSDictionary *response, NSString *error, NSString *message) {
    check([response[@"success"] isEqual:@NO]
              && [response[@"error"] isEqualToString:error]
              && [response[@"delivery_disposition"] isEqualToString:@"not_started"],
          message);
}

static NSDictionary *stickerParams(NSDictionary *overrides) {
    NSMutableDictionary *params = [@{
        @"chatGuid": @"iMessage;-;+15550000000", @"filePath": @"/nonexistent/sticker.png",
        @"contentHash": @"00", @"accessibilityLabel": @"Sticker",
        @"pixelWidth": @1, @"pixelHeight": @1
    } mutableCopy];
    [params addEntriesFromDictionary:overrides];
    return params;
}

int main(void) {
    @autoreleasepool {
        // A refusal before dispatch says nothing was sent, so the caller can
        // try again or send another way instead of treating it as maybe sent.
        checkNotStarted(handleSendAttachment(1, @{@"filePath": @"/nonexistent/file.png"}),
                        @"Missing chatGuid", @"An attachment without a chat was not started");
        checkNotStarted(handleSendAttachment(2, @{@"chatGuid": @"iMessage;-;+15550000000",
                                                  @"filePath": @"/nonexistent/file.png"}),
                        @"File not found: /nonexistent/file.png",
                        @"An attachment whose file is missing was not started");

        checkNotStarted(handleSendSticker(3, stickerParams(@{@"chatGuid": @""})),
                        @"Missing chatGuid", @"A sticker without a chat was not started");
        checkNotStarted(handleSendSticker(4, stickerParams(@{@"selectedMessageGuid": @"p:x/guid"})),
                        @"Malformed sticker target", @"A sticker with a malformed target was not started");
        checkNotStarted(handleSendSticker(5, stickerParams(@{@"targetPartIndex": @1})),
                        @"targetPartIndex requires selectedMessageGuid",
                        @"A sticker part without a target was not started");

        printf("Bridge attachment refusal tests: %lu failure(s)\n", (unsigned long)failures);
        return failures ? 1 : 0;
    }
}
