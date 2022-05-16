package keysign

// Request request to sign a message
type Request struct {
	PoolPubKey    string   `json:"pool_pub_key"` // pub key of the pool that we would like to send this message from
	Message       string   `json:"message"`      // base64 encoded message to be signed
	SignerPubKeys []string `json:"signer_pub_keys"`
}

func NewRequest(pk, msg string, signers []string) Request {
	return Request{
		PoolPubKey:    pk,
		Message:       msg,
		SignerPubKeys: signers,
	}
}
