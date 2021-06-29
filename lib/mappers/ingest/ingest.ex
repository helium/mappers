defmodule Mappers.Ingest do
  alias Mappers.Uplink
  alias Mappers.Uplinks
  alias Mappers.H3
  alias Mappers.H3.Links
  alias Mappers.UplinkHeard
  alias Mappers.UplinksHeard
  alias Mappers.Ingest

  defmodule IngestUplinkResponse do
    @fields [
      :uplink,
      :hotspots,
      :status
    ]
    @derive {Jason.Encoder, only: @fields}
    defstruct uplink: Uplink, hotspots: [UplinkHeard], status: nil
  end

  def ingest_uplink(message) do
    # validate that message geo values actually make sense
    Ingest.Validate.validate_message(message)
    |> case do
      {:error, reason} ->
        %{error: reason}

      {:ok, hotspots} ->
        # create new h3_res9 record if it doesn't exist
        H3.create(message)
        |> case do
          {:error, reason} ->
            %{error: reason}

          {:ok, h3_res9} ->
            h3_res9_id = h3_res9.id

            # create uplink record
            Uplinks.create(message)
            |> case do
              {:error, reason} ->
                %{error: reason}

              {:ok, uplink} ->
                uplink_id = uplink.id

                # create uplinks heard
                UplinksHeard.create(hotspots, uplink_id)
                |> case do
                  {:error, reason} ->
                    %{error: reason}

                  {:ok, uplinks_heard} ->
                    # create h3/uplink link
                    Links.create(h3_res9_id, uplink_id)
                    |> case do
                      {:error, reason} ->
                        %{error: reason}

                      {:ok, _} ->
                        %IngestUplinkResponse{
                          uplink: uplink,
                          hotspots: uplinks_heard,
                          status: "success"
                        }
                    end
                end
            end
        end
    end
  end
end
