module StatsBaseExt

using SQLStore
import StatsBase

StatsBase.sample(query, tbl::SQLStore.Table, args...; kwargs...) = SQLStore.sample(query, tbl, args...; kwargs...)
StatsBase.sample(tbl::SQLStore.Table, args...; kwargs...) = SQLStore.sample(tbl, args...; kwargs...)

end
