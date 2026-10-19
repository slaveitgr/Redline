// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2019 Juan Palacios <jpalaciosdev@gmail.com>

#include "sysfswriter.h"

#include "common/fileutils.h"
#include <exception>
#include <fstream>
#include <spdlog/spdlog.h>

void SysfsWriter::write(std::filesystem::path const &sysfsEntry,
                        std::string const &value)
{
  if (!Utils::File::isFilePathValid(sysfsEntry)) {
    SPDLOG_DEBUG("Invalid file path {}", sysfsEntry.c_str());
    return;
  }

  if (!isSysfsPath(sysfsEntry)) {
    SPDLOG_DEBUG("{} is not a sysfs path. Value {} wont be written.",
                 sysfsEntry.c_str(), value);
    return;
  }

  std::ofstream file(sysfsEntry);
  if (!file.is_open()) {
    SPDLOG_DEBUG("Cannot write {} to file {}", value, sysfsEntry.c_str());
    return;
  }

  file << value << std::endl;
}

bool SysfsWriter::isSysfsPath(std::filesystem::path const &path) const
{
  try {
    const auto canonical=std::filesystem::canonical(path);
    const auto location=canonical.string();
    const auto attribute=canonical.filename().string();
    // Public Redline delegates GPU control exclusively to the GPU engine.
    // This helper can only write supported CPU frequency/EPP attributes.
    if(location.rfind("/sys/devices/system/cpu/",0)!=0) return false;
    return attribute=="scaling_governor" || attribute=="scaling_min_freq" ||
           attribute=="scaling_max_freq" || attribute=="energy_performance_preference";

  }
  catch (std::exception const &e) {
    SPDLOG_DEBUG(e.what());
  }
  return false;
}
