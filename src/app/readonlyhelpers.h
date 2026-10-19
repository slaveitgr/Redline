// SPDX-License-Identifier: GPL-3.0-or-later
// Redline fork: unprivileged preview adapters. Hardware command queues are discarded.
#pragma once
#include "helper/ihelpercontrol.h"
#include "helper/ihelpermonitor.h"
#include "helper/ihelpersysctl.h"
#include "core/icommandqueue.h"
#include <QByteArray>
class ReadOnlyHelperControl final : public IHelperControl {
 public: void init(units::time::millisecond_t) override {} void stop() override {}
};
class ReadOnlyHelperSysCtl final : public IHelperSysCtl {
 public: void init() override {} void apply(ICommandQueue &q) override { (void)q.toRawData(); }
 void logCommands(bool) override {}
};
class ReadOnlyHelperMonitor final : public IHelperMonitor {
 public: void addObserver(std::shared_ptr<Observer>) override {}
 void removeObserver(std::shared_ptr<Observer> const &) override {}
 void init() override {} void watchApp(std::string const &) override {}
 void forgetApp(std::string const &) override {}
};
