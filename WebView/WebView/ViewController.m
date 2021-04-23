//
//  ViewController.m
//  WebView
//
//  Created by zhoushaowen on 2021/4/12.
//

#import "ViewController.h"
#import <WebKit/WebKit.h>
#import <SWExtension.h>

//static  NSString *const schemeString = @"dev.jbf.aijk.net";
static  NSString *const schemeString = @"com.dev.jbf.aijk.net";


@interface ViewController ()<WKNavigationDelegate>
@property (weak, nonatomic) IBOutlet WKWebView *webView;
@property (nonatomic,weak) UITextField *tf;
@property (nonatomic,copy) NSString *originalWeiXinUrl;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
        
    self.webView.navigationDelegate = self;
    [self.webView addObserver:self forKeyPath:@"canGoBack" options:NSKeyValueObservingOptionInitial context:nil];
    self.navigationItem.rightBarButtonItems = @[[[UIBarButtonItem alloc] initWithTitle:@"清除缓存" style:UIBarButtonItemStylePlain target:self action:@selector(removeCache)],[[UIBarButtonItem alloc] initWithTitle:@"重新输入地址" style:UIBarButtonItemStylePlain target:self action:@selector(reload)]];
    [self reload];
}

- (void)backAction {
    if(self.webView.canGoBack){
        [self.webView goBack];
    }
}

- (void)removeCache {
    [self.view sw_showHUD];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:[NSSet setWithArray:@[WKWebsiteDataTypeDiskCache,WKWebsiteDataTypeMemoryCache,WKWebsiteDataTypeCookies]] modifiedSince:[NSDate dateWithTimeIntervalSince1970:0] completionHandler:^{
        [self.view sw_showHUDWithMessage:@"清除成功" hideWithDelay:1.5f];
    }];
}

- (void)reload {
    __weak typeof(self) weakSelf = self;
    [self sw_presentTextFieldAlertWithAlertTitle:@"请输入地址" alertMessgae:nil actionTitles:@[@"加载"] styleArray:NULL textFieldConfigurationHandler:^(UITextField *textField) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.tf = textField;
        strongSelf.tf.text = @"http://dev.yjjk.1daas.com/#/index";
    } handler:^(SWAlertAction *action) {
        if(self.tf.text.sw_trimming.length < 1){
            [self.view sw_showHUDWithMessage:@"地址不能为空" hideWithDelay:1.5f];
            return;
        }
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.tf.text?:@""]]];
    } completion:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if([keyPath isEqualToString:@"canGoBack"]){
        self.navigationItem.leftBarButtonItem = self.webView.canGoBack? [[UIBarButtonItem alloc] initWithTitle:@"返回" style:UIBarButtonItemStylePlain target:self action:@selector(backAction)]:nil;
    }
}

- (void)dealloc
{
    if(self.isViewLoaded){
        [self.webView removeObserver:self forKeyPath:@"canGoBack"];
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSString *urlStr = navigationAction.request.URL.absoluteString;
    NSLog(@"urlStr:%@",urlStr);
    NSURL *payURL = [NSURL URLWithString:urlStr];
    NSString *decodeUrlStr = [payURL.absoluteString stringByRemovingPercentEncoding];
    NSLog(@"decodeUrlStr:%@",decodeUrlStr);
    if ([urlStr hasPrefix:@"alipays://"] || [urlStr hasPrefix:@"alipay://"] || [urlStr hasPrefix:@"weixin://wap/pay"] ) {
                
        NSString *replaceStr = @"\"fromAppUrlScheme\":\"alipays\"";
        if([decodeUrlStr rangeOfString:replaceStr].location != NSNotFound){
            NSString *replacedUrlStr = [decodeUrlStr stringByReplacingOccurrencesOfString:replaceStr withString:[NSString stringWithFormat:@"\"fromAppUrlScheme\":\"%@\"",schemeString]];
            NSLog(@"replacedUrlStr:%@",replacedUrlStr);
            [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[replacedUrlStr stringByAddingPercentEscapesUsingEncoding:   NSUTF8StringEncoding]]]];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
        
        if (@available(iOS 10.0, *)) {
            [[UIApplication sharedApplication] openURL:payURL options:@{UIApplicationOpenURLOptionUniversalLinksOnly: @NO} completionHandler:^(BOOL success) {
                
            }];
        } else {
            // Fallback on earlier versions
            [[UIApplication sharedApplication] openURL:payURL];
        }
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    else if ([urlStr hasPrefix:@"https://wx.tenpay.com/cgi-bin/mmpayweb-bin/checkmweb"] && [urlStr rangeOfString:[@"redirect_url=" stringByAppendingString:schemeString]].location == NSNotFound){
        NSString *replaceScheme = [[[[decodeUrlStr componentsSeparatedByString:@"redirect_url="] lastObject] componentsSeparatedByString:@"?tradeNo"] firstObject]?:@"";
        if ([decodeUrlStr rangeOfString:replaceScheme].location != NSNotFound){
            decisionHandler(WKNavigationActionPolicyCancel);
            NSString *replacedUrlStr = [decodeUrlStr stringByReplacingOccurrencesOfString:replaceScheme withString:[NSString stringWithFormat:@"%@://",schemeString]];
            NSLog(@"replacedUrlStr:%@",replacedUrlStr);
            self.originalWeiXinUrl = [decodeUrlStr componentsSeparatedByString:@"redirect_url="].lastObject;
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[replacedUrlStr stringByAddingPercentEscapesUsingEncoding:   NSUTF8StringEncoding]]];
            [request setValue:[NSString stringWithFormat:@"%@://",schemeString] forHTTPHeaderField:@"Referer"];
            [webView loadRequest:request];
            return;
        }
    }
    else if ([urlStr hasPrefix:[NSString stringWithFormat:@"%@://",schemeString]]){
        //解决微信支付返回的时候白屏
        if([webView canGoBack]){
            [webView goBack];
        }
        //重新加载被替换之前的redirect_url
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.originalWeiXinUrl]];
        [request setTimeoutInterval:10];
        [webView loadRequest:request];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    decisionHandler(WKNavigationActionPolicyAllow);
}




@end
