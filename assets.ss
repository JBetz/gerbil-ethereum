;; Support for multiple classes of assets in a contract
;; TODO: add support on the client side in the same classes, too.
;; TODO: make that part of support of assets on multiple blockchains!

(export #t)
(import
  :clan/poo/poo
  ./assembly ./types ./ethereum ./abi ./contract-runtime)

(.def (Ether @ UInt96 ;; or should it just be UInt256 ???
       .length-in-bytes .length-in-bits)
  .asset-code: 0
  .decimals: 18
  .denominator: (expt 10 .decimals)
  .Address: Address
  .deposit!: ;; (EVMThunk <-) <- (EVMThunk .Address <-) (EVMThunk @ <-) (EVMThunk <- Bool)
  (lambda (sender amount _require! _tmp@)
    (&begin
     ;; sender CALLER EQ require! ;; for ETH, we don't really care about the sender
     deposit amount &safe-add deposit-set!)) ;; maybe just [ADD] or [(&safe-add/n-bits .length-in-bits)] ?
  ;; NB: The above crucially depends on the end-of-transaction code including the below check,
  ;; that must be AND'ed with all other checks before [&require!]
  .commit-check?: ;; (EVMThunk Bool <-)
  (&begin deposit CALLVALUE EQ)
  withdraw!: ;; (EVMThunk <-) <- (EVMThunk .Address <-) (EVMThunk @ <-) (EVMThunk <- Bool)
  (lambda (recipient amount require! _tmp@)
    (&begin 0 DUP1 DUP1 DUP1 amount recipient GAS CALL require!))) ;; Transfer! -- gas address value 0 0 0 0

(.def (ERC20 @ UInt256 ;; https://eips.ethereum.org/EIPS/eip-20
       .contract-address ;; : Address
       .name ;; : String ;; full name, e.g. "FooToken"
       .symbol ;; : Symbol ;; symbol, typically a TLA, e.g. 'FOO
       .decimals) ;; : Nat ;; number of decimals by which to divide the integer amount to get token amount
  .asset-code: .contract-address
  .denominator: (expt 10 .decimals)
  .Address: Address
  ;; function balanceOf(address _owner) public view returns (uint256 balance)
  ;; function transfer(address _to, uint256 _value) public returns (bool success)
  ;; function transferFrom(address _from, address _to, uint256 _value) public returns (bool success)
  ;; function approve(address _spender, uint256 _value) public returns (bool success)
  ;; NB: always reset the approve value to 0 before to set it again to a different non-zero value.
  ;; function allowance(address _owner, address _spender) public view returns (uint256 remaining)
  ;; Events:
  ;; event Transfer(address indexed _from, address indexed _to, uint256 _value)
  ;; event Approval(address indexed _owner, address indexed _spender, uint256 _value)
  .transferFrom-selector: (selector<-function-signature ["transferFrom" Address Address UInt256])
  .deposit!: ;; (EVMThunk <-) <- (EVMThunk .Address <-) (EVMThunk Amount <-) UInt16
  (lambda (sender amount require! tmp@)
    ;; instead of [brk] doing [brk@ MLOAD], cache it on stack and have
    ;; a locals mechanism that binds brk to that?
    ;; Or could/should we be using a fixed buffer for these things?
    ;; Note that the transfer must have been preapproved by the sender.
    ;; TODO: is that how we check the result? Or do we need to check the success from the RET area?
    (&begin
     .transferFrom-selector (&mstoreat/pad-after tmp@ 4)
     sender (&mstoreat (+ tmp@ 4)) ;; TODO: should this be right-padded instead of left-padded??? TEST IT!
     ADDRESS (&mstoreat (+ tmp@ 36))
     amount (&mstoreat (+ tmp@ 68))
     32 tmp@ 100 DUP2 0 .contract-address GAS CALL
     (&mloadat tmp@) AND require!)) ;; check that both the was successful and its boolean result true
  .commit-check?: #f ;; (OrFalse (EVMThunk Bool <-)) ;; the ERC20 already manages its accounting invariants
  .approve-selector: (selector<-function-signature ["approve" Address UInt256]) ;; returns bool
  withdraw!: ;; (EVMThunk <-) <- (EVMThunk .Address <-) (EVMThunk @ <-) (EVMThunk <- Bool) UInt16
  (lambda (recipient amount require! tmp@)
    (&begin
     .approve-selector (&mstoreat/pad-after tmp@ 4)
     recipient (&mstoreat (+ tmp@ 4))
     amount (&mstoreat (+ tmp@ 36))
     32 tmp@ 68 DUP2 0 .contract-address GAS CALL
     (&mloadat tmp@) AND require!))) ;; check that both the was successful and its boolean result true
