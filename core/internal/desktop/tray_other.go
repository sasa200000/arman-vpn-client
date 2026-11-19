//go:build !windows && !linux

package desktop

import (
	"errors"

	"github.com/sasa200000/v2rvpn-client/core/internal/service"
)

func RunTray(service.DataPaths, bool) error {
	return errors.New("the tray icon is available on Windows and Linux; open the dashboard instead")
}
