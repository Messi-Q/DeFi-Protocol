package blame

import (
	. "gopkg.in/check.v1"

	"gitlab.com/thorchain/tss/go-tss/messages"
)

type RoundMgrSuite struct{}

var _ = Suite(&RoundMgrSuite{})

func (ShareMgrSuite) TestTssRoundMgr(c *C) {
	mgr := NewTssRoundMgr()
	w1 := messages.WireMessage{
		Routing:   nil,
		RoundInfo: "test1",
		Message:   nil,
		Sig:       nil,
	}
	mgr.Set("test1", &w1)
	w2 := messages.WireMessage{
		Routing:   nil,
		RoundInfo: "test2",
		Message:   nil,
		Sig:       nil,
	}

	mgr.Set("test2", &w2)
	w3 := messages.WireMessage{
		Routing:   nil,
		RoundInfo: "test3",
		Message:   nil,
		Sig:       nil,
	}
	mgr.Set("test3", &w3)
	ret := mgr.Get("test4")
	c.Assert(ret, IsNil)

	ret = mgr.Get("test2")
	c.Assert(ret.RoundInfo, Equals, "test2")
}
