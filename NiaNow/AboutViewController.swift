//
//  AboutViewController.swift
//  NiaNow
//
//  Created by David Brownstone on 07/07/2017.
//  Copyright © 2017 David Brownstone. All rights reserved.
//

import UIKit
import MBProgressHUD

class AboutViewController: UIViewController, UIWebViewDelegate {

    @IBOutlet weak var theWebview: UIWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        //
        theWebview.delegate = self
        let url = NSURL (string: "https://nianow.com/about-nia");
        let requestObj = NSURLRequest(url: url! as URL);
        startSpinning(urlString: "loading web page...",sender: self)
        theWebview.loadRequest(requestObj as URLRequest);
    }

    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        stopSpinning(sender: self)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    func startSpinning(urlString:NSString, sender:UIViewController) {
        DispatchQueue.main.async {
            () -> Void in
            let spinningActivity = MBProgressHUD.showAdded(to: sender.view,animated:true)
            spinningActivity.label.text = urlString as String
        }
    }
    
    func stopSpinning(sender:UIViewController) {
        DispatchQueue.main.async {
            () -> Void in
            MBProgressHUD.hide(for:self.view, animated:true)
        }
    }
}
