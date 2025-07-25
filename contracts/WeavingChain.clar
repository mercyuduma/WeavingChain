;; WeavingChain: Textile Weaving and Fiber Arts Reward System
;; Version: 1.0.0

;; Constants
(define-constant LOOM_CAPACITY u1800000)
(define-constant BASE_WEAVING_REWARD u22)
(define-constant TEXTILE_BONUS u8)
(define-constant MAX_WEAVER_LEVEL u12)
(define-constant ERR_INVALID_WEAVING_ACTIVITY u1)
(define-constant ERR_NO_WEAVING_TOKENS u2)
(define-constant ERR_LOOM_CAPACITY_EXCEEDED u3)
(define-constant BLOCKS_PER_WEAVING_SEASON u1728)
(define-constant THREAD_PRESERVATION_MULTIPLIER u4)
(define-constant MIN_PRESERVATION_PERIOD u864)
(define-constant EARLY_WEAVING_PENALTY u15)

;; Data Variables
(define-data-var total-weaving-tokens-distributed uint u0)
(define-data-var total-weaving-activities uint u0)
(define-data-var loom-supervisor principal tx-sender)

;; Data Maps
(define-map weaver-activities principal uint)
(define-map weaver-weaving-tokens principal uint)
(define-map weaving-activity-start-time principal uint)
(define-map weaver-textile-level principal uint)
(define-map weaver-last-activity principal uint)
(define-map weaver-preserved-thread principal uint)
(define-map weaver-preservation-start-block principal uint)

;; Public Functions
(define-public (start-weaving-activity (pattern-complexity uint))
  (let
    (
      (weaver tx-sender)
    )
    (asserts! (> pattern-complexity u0) (err ERR_INVALID_WEAVING_ACTIVITY))
    (map-set weaving-activity-start-time weaver burn-block-height)
    (ok true)
  ))

(define-public (complete-weaving-project (pattern-complexity uint))
  (let
    (
      (weaver tx-sender)
      (start-block (default-to u0 (map-get? weaving-activity-start-time weaver)))
      (blocks-weaving (- burn-block-height start-block))
      (last-activity-block (default-to u0 (map-get? weaver-last-activity weaver)))
      (textile-level (default-to u0 (map-get? weaver-textile-level weaver)))
      (capped-textile (if (<= textile-level MAX_WEAVER_LEVEL) textile-level MAX_WEAVER_LEVEL))
      (weaving-reward (+ BASE_WEAVING_REWARD (* capped-textile TEXTILE_BONUS)))
    )
    (asserts! (and (> start-block u0) (>= blocks-weaving pattern-complexity)) (err ERR_INVALID_WEAVING_ACTIVITY))
    
    (map-set weaver-activities weaver (+ (default-to u0 (map-get? weaver-activities weaver)) u1))
    (map-set weaver-weaving-tokens weaver (+ (default-to u0 (map-get? weaver-weaving-tokens weaver)) weaving-reward))
    
    (if (< (- burn-block-height last-activity-block) BLOCKS_PER_WEAVING_SEASON)
      (map-set weaver-textile-level weaver (+ textile-level u1))
      (map-set weaver-textile-level weaver u1)
    )
    
    (map-set weaver-last-activity weaver burn-block-height)
    (var-set total-weaving-activities (+ (var-get total-weaving-activities) u1))
    (var-set total-weaving-tokens-distributed (+ (var-get total-weaving-tokens-distributed) weaving-reward))
    
    (asserts! (<= (var-get total-weaving-tokens-distributed) LOOM_CAPACITY) (err ERR_LOOM_CAPACITY_EXCEEDED))
    (ok weaving-reward)
  ))

(define-public (claim-weaving-rewards)
  (let
    (
      (weaver tx-sender)
      (token-balance (default-to u0 (map-get? weaver-weaving-tokens weaver)))
    )
    (asserts! (> token-balance u0) (err ERR_NO_WEAVING_TOKENS))
    (map-set weaver-weaving-tokens weaver u0)
    (ok token-balance)
  ))

;; Thread Preservation Features
(define-public (preserve-thread (amount uint))
  (let
    (
      (weaver tx-sender)
    )
    (asserts! (> amount u0) (err ERR_INVALID_WEAVING_ACTIVITY))
    (asserts! (>= (var-get total-weaving-tokens-distributed) amount) (err ERR_LOOM_CAPACITY_EXCEEDED))
    
    (map-set weaver-preserved-thread weaver amount)
    (map-set weaver-preservation-start-block weaver burn-block-height)
    (var-set total-weaving-tokens-distributed (- (var-get total-weaving-tokens-distributed) amount))
    (ok amount)
  ))

(define-public (release-preserved-thread)
  (let
    (
      (weaver tx-sender)
      (preserved-amount (default-to u0 (map-get? weaver-preserved-thread weaver)))
      (preservation-start-block (default-to u0 (map-get? weaver-preservation-start-block weaver)))
      (blocks-preserved (- burn-block-height preservation-start-block))
      (penalty (if (< blocks-preserved MIN_PRESERVATION_PERIOD) (/ (* preserved-amount EARLY_WEAVING_PENALTY) u100) u0))
      (final-amount (- preserved-amount penalty))
    )
    (asserts! (> preserved-amount u0) (err ERR_NO_WEAVING_TOKENS))
    
    (map-set weaver-preserved-thread weaver u0)
    (map-set weaver-preservation-start-block weaver u0)
    (var-set total-weaving-tokens-distributed (+ (var-get total-weaving-tokens-distributed) final-amount))
    (ok final-amount)
  ))

;; Read-Only Functions
(define-read-only (get-weaving-activity-count (user principal))
  (default-to u0 (map-get? weaver-activities user)))

(define-read-only (get-weaving-token-balance (user principal))
  (default-to u0 (map-get? weaver-weaving-tokens user)))

(define-read-only (get-textile-level (user principal))
  (default-to u0 (map-get? weaver-textile-level user)))

(define-read-only (get-loom-stats)
  {
    total-weaving-activities: (var-get total-weaving-activities),
    total-weaving-tokens-distributed: (var-get total-weaving-tokens-distributed)
  })

;; Private Functions
(define-private (is-loom-supervisor)
  (is-eq tx-sender (var-get loom-supervisor)))