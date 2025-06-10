(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-campaign-ended (err u104))
(define-constant err-campaign-active (err u105))
(define-constant err-goal-not-reached (err u106))
(define-constant err-goal-reached (err u107))
(define-constant err-no-contribution (err u108))
(define-constant err-already-claimed (err u109))

(define-map campaigns
  { campaign-id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    goal: uint,
    deadline: uint,
    total-raised: uint,
    active: bool,
    funds-claimed: bool
  }
)

(define-map contributions
  { campaign-id: uint, contributor: principal }
  { amount: uint, refunded: bool }
)

(define-data-var next-campaign-id uint u1)

(define-public (create-campaign (title (string-ascii 100)) (description (string-ascii 500)) (goal uint) (duration uint))
  (let
    (
      (campaign-id (var-get next-campaign-id))
      (deadline (+ stacks-block-height duration))
    )
    (asserts! (> goal u0) err-invalid-amount)
    (asserts! (> duration u0) err-invalid-amount)
    (map-set campaigns
      { campaign-id: campaign-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        goal: goal,
        deadline: deadline,
        total-raised: u0,
        active: true,
        funds-claimed: false
      }
    )
    (var-set next-campaign-id (+ campaign-id u1))
    (ok campaign-id)
  )
)

(define-public (contribute (campaign-id uint) (amount uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
      (existing-contribution (map-get? contributions { campaign-id: campaign-id, contributor: tx-sender }))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (get active campaign) err-campaign-ended)
    (asserts! (<= stacks-block-height (get deadline campaign)) err-campaign-ended)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (match existing-contribution
      existing-contrib
      (map-set contributions
        { campaign-id: campaign-id, contributor: tx-sender }
        { amount: (+ (get amount existing-contrib) amount), refunded: false }
      )
      (map-set contributions
        { campaign-id: campaign-id, contributor: tx-sender }
        { amount: amount, refunded: false }
      )
    )
    
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { total-raised: (+ (get total-raised campaign) amount) })
    )
    
    (ok true)
  )
)

(define-public (claim-funds (campaign-id uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender (get creator campaign)) err-owner-only)
    (asserts! (> stacks-block-height (get deadline campaign)) err-campaign-active)
    (asserts! (>= (get total-raised campaign) (get goal campaign)) err-goal-not-reached)
    (asserts! (not (get funds-claimed campaign)) err-already-claimed)
    
    (try! (as-contract (stx-transfer? (get total-raised campaign) tx-sender (get creator campaign))))
    
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { active: false, funds-claimed: true })
    )
    
    (ok (get total-raised campaign))
  )
)

(define-public (request-refund (campaign-id uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
      (contribution (unwrap! (map-get? contributions { campaign-id: campaign-id, contributor: tx-sender }) err-no-contribution))
    )
    (asserts! (> stacks-block-height (get deadline campaign)) err-campaign-active)
    (asserts! (< (get total-raised campaign) (get goal campaign)) err-goal-reached)
    (asserts! (not (get refunded contribution)) err-already-claimed)
    
    (try! (as-contract (stx-transfer? (get amount contribution) tx-sender tx-sender)))
    
    (map-set contributions
      { campaign-id: campaign-id, contributor: tx-sender }
      (merge contribution { refunded: true })
    )
    
    (ok (get amount contribution))
  )
)

(define-public (end-campaign (campaign-id uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender (get creator campaign)) err-owner-only)
    (asserts! (> stacks-block-height (get deadline campaign)) err-campaign-active)
    
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { active: false })
    )
    
    (ok true)
  )
)

(define-read-only (get-campaign (campaign-id uint))
  (map-get? campaigns { campaign-id: campaign-id })
)

(define-read-only (get-contribution (campaign-id uint) (contributor principal))
  (map-get? contributions { campaign-id: campaign-id, contributor: contributor })
)

(define-read-only (get-campaign-status (campaign-id uint))
  (match (map-get? campaigns { campaign-id: campaign-id })
    campaign
    (ok {
      goal-reached: (>= (get total-raised campaign) (get goal campaign)),
      deadline-passed: (> stacks-block-height (get deadline campaign)),
      active: (get active campaign),
      funds-claimed: (get funds-claimed campaign),
      total-raised: (get total-raised campaign),
      goal: (get goal campaign),
      deadline: (get deadline campaign)
    })
    err-not-found
  )
)

(define-read-only (can-claim-funds (campaign-id uint))
  (match (map-get? campaigns { campaign-id: campaign-id })
    campaign
    (ok (and
      (> stacks-block-height (get deadline campaign))
      (>= (get total-raised campaign) (get goal campaign))
      (not (get funds-claimed campaign))
    ))
    err-not-found
  )
)

(define-read-only (can-request-refund (campaign-id uint) (contributor principal))
  (match (map-get? campaigns { campaign-id: campaign-id })
    campaign
    (match (map-get? contributions { campaign-id: campaign-id, contributor: contributor })
      contribution
      (ok (and
        (> stacks-block-height (get deadline campaign))
        (< (get total-raised campaign) (get goal campaign))
        (not (get refunded contribution))
      ))
      err-no-contribution
    )
    err-not-found
  )
)

(define-read-only (get-next-campaign-id)
  (var-get next-campaign-id)
)