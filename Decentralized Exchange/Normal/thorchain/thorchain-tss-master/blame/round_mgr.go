package blame

import (
	"sync"

	"gitlab.com/thorchain/tss/go-tss/messages"
)

type RoundMgr struct {
	storedMsg   map[string]*messages.WireMessage
	storeLocker *sync.Mutex
}

func NewTssRoundMgr() *RoundMgr {
	return &RoundMgr{
		storeLocker: &sync.Mutex{},
		storedMsg:   make(map[string]*messages.WireMessage),
	}
}

func (tr *RoundMgr) Get(key string) *messages.WireMessage {
	tr.storeLocker.Lock()
	defer tr.storeLocker.Unlock()
	ret, ok := tr.storedMsg[key]
	if !ok {
		return nil
	}
	return ret
}

func (tr *RoundMgr) Set(key string, msg *messages.WireMessage) {
	tr.storeLocker.Lock()
	defer tr.storeLocker.Unlock()
	tr.storedMsg[key] = msg
}

func (tr *RoundMgr) GetByRound(roundInfo string) []string {
	var standbyNodes []string
	for _, el := range tr.storedMsg {
		if el.RoundInfo == roundInfo {
			standbyNodes = append(standbyNodes, el.Routing.From.Id)
		}
	}
	return standbyNodes
}
