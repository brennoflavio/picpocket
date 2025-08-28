"""
Copyright (C) 2025  Brenno Flávio de Almeida

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 3.

calpal is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
"""

import calendar
from datetime import datetime


def add_month(date: datetime, months: int) -> datetime:
    target_month = date.month + months
    target_year = date.year

    while target_month > 12:
        target_month -= 12
        target_year += 1

    while target_month < 1:
        target_month += 12
        target_year -= 1

    last_day_of_target_month = calendar.monthrange(target_year, target_month)[1]

    target_day = min(date.day, last_day_of_target_month)

    return date.replace(year=target_year, month=target_month, day=target_day)
