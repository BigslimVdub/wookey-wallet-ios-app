//
//  AssetsTokenViewController.swift


import UIKit

class AssetsTokenViewController: BaseViewController {
    
    
    // MARK: - Properties (Pivate)
    
    private let tokenAssets: Assets
    
    private let viewModel: AssetsTokenViewModel
    
    
    // MARK: - Properties (Lazy)

    
    private lazy var contentView: AutoLayoutScrollView = {
        return AutoLayoutScrollView(frame: view.bounds)
    }()
    
    private lazy var tokenAssetsView: AssetsTokenView = {
        return AssetsTokenView()
    }()
    
    private lazy var tokenTransactionsView: CAPSPageMenu = {
        let viewControllers = Array<TransactionsType>([.all, .in, .out]).map({ TransactionListController.init(type: $0) })
        let _frame = view.frame.inset(by: UIEdgeInsets(top: 0, left: 0, bottom: UIApplication.shared.statusBarFrame.height + 44, right: 0))
        return CAPSPageMenu.init(viewControllers: viewControllers, frame: _frame, pageMenuOptions: CAPSPageMenuOption.itemsScaleToFillOptions())
    }()
    
    //滑动是否进入结束状态
    private lazy var isScrollEND = { return Observable<Bool>(false) }()
    
    
    // MARK: - Life Cycles
    
    required init(tokenAssets: Assets, pwd: String) {
        self.tokenAssets = tokenAssets
        self.viewModel = AssetsTokenViewModel.init(asset: tokenAssets, pwd: pwd)
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func configureUI() {
        super.configureUI()
        
        do /// Self
        {
            navigationItem.title = tokenAssets.token
            view.backgroundColor = AppTheme.Color.tableView_bg
        }
        
        do /// Subviews
        {
            contentView.delegate = self
            view.addSubview(contentView)
            
            tokenAssetsView.tokenIconView.image = tokenAssets.icon
            tokenAssetsView.balanceLabel.text = tokenAssets.remain
            
            tokenAssetsView.progressBar.progress = 0
            tokenAssetsView.tokenAddress.text = tokenAssets.wallet?.address
            
            contentView.contentView.addSubViews([
                tokenAssetsView,
                tokenTransactionsView.view,
            ])
            
            tokenAssetsView.snp.makeConstraints { (make) in
                make.top.left.right.equalToSuperview()
            }
            tokenTransactionsView.view.snp.makeConstraints { (make) in
                make.top.equalTo(tokenAssetsView.snp.bottom).offset(10)
                make.left.right.equalToSuperview()
                make.height.equalTo(tokenTransactionsView.view.height)
            }
            
            
            contentView.resizeContentLayout()
            
        }
    }
    
    override func configureBinds() {
        super.configureBinds()
        
        do //// Actions
        {
            navigationItem.rightBarButtonItem = UIBarButtonItem.init(image: UIImage(named: "navigationItem_refresh"), style: .plain, target: self, action: #selector(self.refreshAction))
            tokenAssetsView.sendBtn.addTarget(self, action: #selector(self.sendAction), for: .touchUpInside)
            tokenAssetsView.receiveBtn.addTarget(self, action: #selector(self.receiveAction), for: .touchUpInside)
            tokenAssetsView.copyBtn.addTarget(self, action: #selector(self.copyAction), for: .touchUpInside)
            
            /// 叠加视图滑动联动
            tokenTransactionsView.controllerArray.forEach({
                guard let vc = $0 as? TransactionListController else { return }
                // 子级结束，进入父级
                vc.isScrollEND.observe(self, eventHandler: { (isEnd, strongSelf) in
                    guard isEnd else { return }
                    strongSelf.isScrollEND.value = false
                })
                // 父级结束，进入子级
                self.isScrollEND.observe(vc, eventHandler: { (isEnd, strongVC) in
                    guard isEnd else { return }
                    strongVC.isScrollEND.value = false
                })
            })
        }
        
        do //// Wallet Syncing
        {
            viewModel.refreshState.observe(navigationItem.rightBarButtonItem!) { (enable, rightBarButtonItem) in
                rightBarButtonItem.isEnabled = enable
            }
            viewModel.sendState.observe(tokenAssetsView.sendBtn) { (enable, btn) in
                btn.isEnabled = enable
            }
            viewModel.reciveState.observe(tokenAssetsView.receiveBtn) { (enable, btn) in
                btn.isEnabled = enable
            }
            viewModel.conncetingState.observe(tokenAssetsView.progressBar) { (connecting, progressBar) in
                progressBar.animating = connecting
            }
            viewModel.progressState.observe(tokenAssetsView.progressBar) { (progress, progressBar) in
                progressBar.progress = progress
            }
            viewModel.statusTextState.observe(tokenAssetsView.progressLabel) { (text, label) in
                label.text = text
            }
            viewModel.balanceState.observe(tokenAssetsView.balanceLabel) { (text, label) in
                label.text = text
            }
            viewModel.historyState.observe(self) { (list, strongSelf) in
                guard let list = list else { return }
                let vc0 = strongSelf.tokenTransactionsView.controllerArray[0] as? TransactionListController
                let vc1 = strongSelf.tokenTransactionsView.controllerArray[1] as? TransactionListController
                let vc2 = strongSelf.tokenTransactionsView.controllerArray[2] as? TransactionListController
                vc0?.dataSource = list[0]
                vc1?.dataSource = list[1]
                vc2?.dataSource = list[2]
                switch strongSelf.tokenTransactionsView.currentPageIndex {
                case 0:
                    vc0?.reloadData()
                case 1:
                    vc1?.reloadData()
                case 2:
                    vc2?.reloadData()
                default:
                    break;
                }
            }
            
            viewModel.init_wallet()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tokenTransactionsView.controllerArray[tokenTransactionsView.currentPageIndex].viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tokenAssetsView.progressBar.willAppear()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tokenAssetsView.progressBar.willDisappear()
    }
    
    deinit {
        dPrint("\(#function) ================================= \(self.classForCoder)")
    }
    
    
    // MARK: - Methods (Action)
    
    @objc private func refreshAction() {
        viewModel.refresh()
    }
    
    @objc private func sendAction() {
        navigationController?.pushViewController(viewModel.toSend(), animated: true)
    }
    
    @objc private func receiveAction() {
        navigationController?.pushViewController(viewModel.toReceive(), animated: true)
    }
    
    @objc private func copyAction() {
        UIPasteboard.general.string = tokenAssets.wallet?.address
        HUD.showSuccess(LocalizedString(key: "copy_success", comment: ""))
    }

}

// MARK: - UIScrollViewDelegate

extension AssetsTokenViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        var limit_offset = tokenAssetsView.height + 10
        if #available(iOS 11.0, *) {
            limit_offset -= scrollView.adjustedContentInset.top - scrollView.contentInset.top
        } else {
            limit_offset -= scrollView.contentInset.top
        }
        guard !isScrollEND.value else {
            scrollView.contentOffset.y = limit_offset
            return
        }
        if scrollView.contentOffset.y >= limit_offset {
            scrollView.contentOffset.y = limit_offset
            isScrollEND.value = true
        }
    }
}
