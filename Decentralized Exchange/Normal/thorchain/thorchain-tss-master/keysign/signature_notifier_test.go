package keysign

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"io/ioutil"
	"sync"
	"testing"
	"time"

	bc "github.com/binance-chain/tss-lib/common"
	"github.com/libp2p/go-libp2p-core/peer"
	tnet "github.com/libp2p/go-libp2p-testing/net"
	mocknet "github.com/libp2p/go-libp2p/p2p/net/mock"
	"github.com/stretchr/testify/assert"

	"gitlab.com/thorchain/tss/go-tss/common"
	"gitlab.com/thorchain/tss/go-tss/p2p"
)

func TestSignatureNotifierHappyPath(t *testing.T) {
	poolPubKey := `thorpub1addwnpepq0ul3xt882a6nm6m7uhxj4tk2n82zyu647dyevcs5yumuadn4uamqx7neak`
	messageToSign := "yhEwrxWuNBGnPT/L7PNnVWg7gFWNzCYTV+GuX3tKRH8="
	buf, err := base64.StdEncoding.DecodeString(messageToSign)
	assert.Nil(t, err)
	messageID, err := common.MsgToHashString(buf)
	assert.Nil(t, err)
	p2p.ApplyDeadline = false
	id1 := tnet.RandIdentityOrFatal(t)
	id2 := tnet.RandIdentityOrFatal(t)
	id3 := tnet.RandIdentityOrFatal(t)
	mn := mocknet.New(context.Background())
	// add peers to mock net

	a1 := tnet.RandLocalTCPAddress()
	a2 := tnet.RandLocalTCPAddress()
	a3 := tnet.RandLocalTCPAddress()

	h1, err := mn.AddPeer(id1.PrivateKey(), a1)
	if err != nil {
		t.Fatal(err)
	}
	p1 := h1.ID()
	h2, err := mn.AddPeer(id2.PrivateKey(), a2)
	if err != nil {
		t.Fatal(err)
	}
	p2 := h2.ID()
	h3, err := mn.AddPeer(id3.PrivateKey(), a3)
	if err != nil {
		t.Fatal(err)
	}
	p3 := h3.ID()
	if err := mn.LinkAll(); err != nil {
		t.Error(err)
	}
	if err := mn.ConnectAllButSelf(); err != nil {
		t.Error(err)
	}
	n1 := NewSignatureNotifier(h1)
	n2 := NewSignatureNotifier(h2)
	n3 := NewSignatureNotifier(h3)
	assert.NotNil(t, n1)
	assert.NotNil(t, n2)
	assert.NotNil(t, n3)
	n1.Start()
	n2.Start()
	n3.Start()
	defer n1.Stop()
	defer n2.Stop()
	defer n3.Stop()
	sigFile := "../test_data/signature_notify/sig1.json"
	content, err := ioutil.ReadFile(sigFile)
	assert.Nil(t, err)
	assert.NotNil(t, content)
	var signature bc.SignatureData
	err = json.Unmarshal(content, &signature)
	assert.Nil(t, err)
	wg := sync.WaitGroup{}
	wg.Add(1)
	go func() {
		defer wg.Done()
		sig, err := n1.WaitForSignature(messageID, buf, poolPubKey, time.Second*30)
		assert.Nil(t, err)
		assert.NotNil(t, sig)
	}()
	assert.Nil(t, n2.BroadcastSignature(messageID, &signature, []peer.ID{
		p1, p3,
	}))
	assert.Nil(t, n3.BroadcastSignature(messageID, &signature, []peer.ID{
		p1, p2,
	}))
	wg.Wait()
}
