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
(define-constant err-milestone-not-found (err u110))
(define-constant err-insufficient-votes (err u111))
(define-constant err-milestone-completed (err u112))
(define-constant err-invalid-milestone (err u113))
(define-constant err-update-not-found (err u114))
(define-constant err-extension-not-found (err u115))
(define-constant err-extension-expired (err u116))
(define-constant err-extension-approved (err u117))

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

(define-map milestones
  { campaign-id: uint, milestone-id: uint }
  {
    description: (string-ascii 200),
    funding-amount: uint,
    votes-required: uint,
    votes-received: uint,
    completed: bool,
    funds-released: bool
  }
)

(define-map milestone-votes
  { campaign-id: uint, milestone-id: uint, voter: principal }
  { voted: bool }
)

(define-map campaign-updates
  { campaign-id: uint, update-id: uint }
  {
    title: (string-ascii 100),
    content: (string-ascii 1000),
    timestamp: uint,
    creator: principal
  }
)

(define-map extension-requests
  { campaign-id: uint }
  {
    new-deadline: uint,
    votes-required: uint,
    votes-received: uint,
    voting-deadline: uint,
    approved: bool,
    applied: bool
  }
)

(define-map extension-votes
  { campaign-id: uint, voter: principal }
  { voted: bool }
)

(define-data-var next-milestone-id uint u1)
(define-data-var next-update-id uint u1)

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

(define-public (create-milestone (campaign-id uint) (description (string-ascii 200)) (funding-amount uint) (votes-required uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
      (milestone-id (var-get next-milestone-id))
    )
    (asserts! (is-eq tx-sender (get creator campaign)) err-owner-only)
    (asserts! (> funding-amount u0) err-invalid-amount)
    (asserts! (> votes-required u0) err-invalid-milestone)
    (asserts! (get active campaign) err-campaign-ended)
    
    (map-set milestones
      { campaign-id: campaign-id, milestone-id: milestone-id }
      {
        description: description,
        funding-amount: funding-amount,
        votes-required: votes-required,
        votes-received: u0,
        completed: false,
        funds-released: false
      }
    )
    
    (var-set next-milestone-id (+ milestone-id u1))
    (ok milestone-id)
  )
)

(define-public (vote-milestone (campaign-id uint) (milestone-id uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
      (milestone (unwrap! (map-get? milestones { campaign-id: campaign-id, milestone-id: milestone-id }) err-milestone-not-found))
      (contribution (unwrap! (map-get? contributions { campaign-id: campaign-id, contributor: tx-sender }) err-no-contribution))
      (existing-vote (map-get? milestone-votes { campaign-id: campaign-id, milestone-id: milestone-id, voter: tx-sender }))
    )
    (asserts! (not (get completed milestone)) err-milestone-completed)
    (asserts! (is-none existing-vote) err-already-claimed)
    
    (map-set milestone-votes
      { campaign-id: campaign-id, milestone-id: milestone-id, voter: tx-sender }
      { voted: true }
    )
    
    (map-set milestones
      { campaign-id: campaign-id, milestone-id: milestone-id }
      (merge milestone { votes-received: (+ (get votes-received milestone) u1) })
    )
    
    (ok true)
  )
)

(define-public (complete-milestone (campaign-id uint) (milestone-id uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
      (milestone (unwrap! (map-get? milestones { campaign-id: campaign-id, milestone-id: milestone-id }) err-milestone-not-found))
    )
    (asserts! (is-eq tx-sender (get creator campaign)) err-owner-only)
    (asserts! (>= (get votes-received milestone) (get votes-required milestone)) err-insufficient-votes)
    (asserts! (not (get completed milestone)) err-milestone-completed)
    
    (map-set milestones
      { campaign-id: campaign-id, milestone-id: milestone-id }
      (merge milestone { completed: true })
    )
    
    (ok true)
  )
)

(define-public (release-milestone-funds (campaign-id uint) (milestone-id uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
      (milestone (unwrap! (map-get? milestones { campaign-id: campaign-id, milestone-id: milestone-id }) err-milestone-not-found))
    )
    (asserts! (is-eq tx-sender (get creator campaign)) err-owner-only)
    (asserts! (get completed milestone) err-insufficient-votes)
    (asserts! (not (get funds-released milestone)) err-already-claimed)
    (asserts! (>= (get total-raised campaign) (get funding-amount milestone)) err-invalid-amount)
    
    (try! (as-contract (stx-transfer? (get funding-amount milestone) tx-sender (get creator campaign))))
    
    (map-set milestones
      { campaign-id: campaign-id, milestone-id: milestone-id }
      (merge milestone { funds-released: true })
    )
    
    (ok (get funding-amount milestone))
  )
)

(define-read-only (get-milestone (campaign-id uint) (milestone-id uint))
  (map-get? milestones { campaign-id: campaign-id, milestone-id: milestone-id })
)

(define-read-only (get-milestone-vote (campaign-id uint) (milestone-id uint) (voter principal))
  (map-get? milestone-votes { campaign-id: campaign-id, milestone-id: milestone-id, voter: voter })
)

(define-read-only (can-vote-milestone (campaign-id uint) (milestone-id uint) (voter principal))
  (match (map-get? campaigns { campaign-id: campaign-id })
    campaign
    (match (map-get? milestones { campaign-id: campaign-id, milestone-id: milestone-id })
      milestone
      (match (map-get? contributions { campaign-id: campaign-id, contributor: voter })
        contribution
        (ok (and
          (not (get completed milestone))
          (is-none (map-get? milestone-votes { campaign-id: campaign-id, milestone-id: milestone-id, voter: voter }))
        ))
        err-no-contribution
      )
      err-milestone-not-found
    )
    err-not-found
  )
)

(define-public (post-update (campaign-id uint) (title (string-ascii 100)) (content (string-ascii 1000)))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
      (update-id (var-get next-update-id))
    )
    (asserts! (is-eq tx-sender (get creator campaign)) err-owner-only)
    (asserts! (> (len title) u0) err-invalid-amount)
    (asserts! (> (len content) u0) err-invalid-amount)
    
    (map-set campaign-updates
      { campaign-id: campaign-id, update-id: update-id }
      {
        title: title,
        content: content,
        timestamp: stacks-block-height,
        creator: tx-sender
      }
    )
    
    (var-set next-update-id (+ update-id u1))
    (ok update-id)
  )
)

(define-read-only (get-update (campaign-id uint) (update-id uint))
  (map-get? campaign-updates { campaign-id: campaign-id, update-id: update-id })
)

(define-read-only (get-latest-update-id)
  (- (var-get next-update-id) u1)
)

(define-read-only (campaign-has-updates (campaign-id uint))
  (let
    (
      (latest-id (get-latest-update-id))
    )
    (if (is-eq latest-id u0)
      false
      (is-some (map-get? campaign-updates { campaign-id: campaign-id, update-id: latest-id }))
    )
  )
)

(define-read-only (get-update-count (campaign-id uint))
  (let
    (
      (latest-id (get-latest-update-id))
      (count u0)
    )
    (fold check-update-exists (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20) { campaign-id: campaign-id, count: u0 })
  )
)

(define-private (check-update-exists (update-id uint) (data { campaign-id: uint, count: uint }))
  (if (is-some (map-get? campaign-updates { campaign-id: (get campaign-id data), update-id: update-id }))
    { campaign-id: (get campaign-id data), count: (+ (get count data) u1) }
    data
  )
)

(define-public (request-extension (campaign-id uint) (additional-blocks uint) (votes-required uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
      (existing-request (map-get? extension-requests { campaign-id: campaign-id }))
    )
    (asserts! (is-eq tx-sender (get creator campaign)) err-owner-only)
    (asserts! (get active campaign) err-campaign-ended)
    (asserts! (> additional-blocks u0) err-invalid-amount)
    (asserts! (> votes-required u0) err-invalid-milestone)
    (asserts! (is-none existing-request) err-already-exists)
    
    (map-set extension-requests
      { campaign-id: campaign-id }
      {
        new-deadline: (+ (get deadline campaign) additional-blocks),
        votes-required: votes-required,
        votes-received: u0,
        voting-deadline: (+ stacks-block-height u144),
        approved: false,
        applied: false
      }
    )
    
    (ok true)
  )
)

(define-public (vote-extension (campaign-id uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
      (extension-request (unwrap! (map-get? extension-requests { campaign-id: campaign-id }) err-extension-not-found))
      (contribution (unwrap! (map-get? contributions { campaign-id: campaign-id, contributor: tx-sender }) err-no-contribution))
      (existing-vote (map-get? extension-votes { campaign-id: campaign-id, voter: tx-sender }))
    )
    (asserts! (<= stacks-block-height (get voting-deadline extension-request)) err-extension-expired)
    (asserts! (not (get approved extension-request)) err-extension-approved)
    (asserts! (is-none existing-vote) err-already-claimed)
    
    (map-set extension-votes
      { campaign-id: campaign-id, voter: tx-sender }
      { voted: true }
    )
    
    (map-set extension-requests
      { campaign-id: campaign-id }
      (merge extension-request { votes-received: (+ (get votes-received extension-request) u1) })
    )
    
    (ok true)
  )
)

(define-public (approve-extension (campaign-id uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
      (extension-request (unwrap! (map-get? extension-requests { campaign-id: campaign-id }) err-extension-not-found))
    )
    (asserts! (is-eq tx-sender (get creator campaign)) err-owner-only)
    (asserts! (>= (get votes-received extension-request) (get votes-required extension-request)) err-insufficient-votes)
    (asserts! (not (get approved extension-request)) err-extension-approved)
    (asserts! (<= stacks-block-height (get voting-deadline extension-request)) err-extension-expired)
    
    (map-set extension-requests
      { campaign-id: campaign-id }
      (merge extension-request { approved: true })
    )
    
    (ok true)
  )
)

(define-public (apply-extension (campaign-id uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
      (extension-request (unwrap! (map-get? extension-requests { campaign-id: campaign-id }) err-extension-not-found))
    )
    (asserts! (is-eq tx-sender (get creator campaign)) err-owner-only)
    (asserts! (get approved extension-request) err-insufficient-votes)
    (asserts! (not (get applied extension-request)) err-already-claimed)
    
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { deadline: (get new-deadline extension-request) })
    )
    
    (map-set extension-requests
      { campaign-id: campaign-id }
      (merge extension-request { applied: true })
    )
    
    (ok (get new-deadline extension-request))
  )
)

(define-read-only (get-extension-request (campaign-id uint))
  (map-get? extension-requests { campaign-id: campaign-id })
)

(define-read-only (get-extension-vote (campaign-id uint) (voter principal))
  (map-get? extension-votes { campaign-id: campaign-id, voter: voter })
)

(define-read-only (can-vote-extension (campaign-id uint) (voter principal))
  (match (map-get? campaigns { campaign-id: campaign-id })
    campaign
    (match (map-get? extension-requests { campaign-id: campaign-id })
      extension-request
      (match (map-get? contributions { campaign-id: campaign-id, contributor: voter })
        contribution
        (ok (and
          (<= stacks-block-height (get voting-deadline extension-request))
          (not (get approved extension-request))
          (is-none (map-get? extension-votes { campaign-id: campaign-id, voter: voter }))
        ))
        err-no-contribution
      )
      err-extension-not-found
    )
    err-not-found
  )
)