//
//  ViewController.swift
//  XWebImage
//
//  Created by ming on 11/14/2017.
//  Copyright (c) 2017 ming. All rights reserved.
//

import UIKit
import XWebImage

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let iv = UIImageView.init(frame: CGRect.init(x: 100, y: 100, width: 100, height: 100))
        view.addSubview(iv)
        iv.xm_setImage(url: "http://pic.sc.chinaz.com/files/pic/pic9/201712/bpic4611.jpg", placeholder: nil, options: [], progressBlock: nil) { (image, error, type, url) in
            
        }
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

