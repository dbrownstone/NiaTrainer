//
//  AboutViewController.swift
//  NiaNow
//
//  Created by David Brownstone on 07/07/2017.
//  Copyright © 2017 David Brownstone. All rights reserved.
//

import UIKit

class AboutViewController: UIViewController {

    @IBOutlet weak var theWebview: UIWebView!
    override func viewDidLoad() {
        super.viewDidLoad()
        //
        // Do any additional setup after loading the view.
        let url = NSURL (string: "https://nianow.com/about-nia");
        let requestObj = NSURLRequest(url: url! as URL);
        theWebview.loadRequest(requestObj as URLRequest);
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
